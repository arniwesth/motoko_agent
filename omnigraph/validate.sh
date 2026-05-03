#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if ! command -v omnigraph >/dev/null 2>&1; then
  echo "omnigraph binary not found on PATH" >&2
  exit 1
fi

if [[ ! -d repo.omni ]]; then
  omnigraph init --schema schema.pg repo.omni
fi

# Load seed data if present (Motoko graph may not be built yet)
if [[ -f seed/data.jsonl ]]; then
  omnigraph load --data seed/data.jsonl >/dev/null 2>&1 || true
fi

read_main() {
  omnigraph read --query queries/decisions.gq --name list_decisions --json
}

count_rows() {
  awk 'BEGIN{n=0} /"row_count"/ {if (match($0, /"row_count"[[:space:]]*:[[:space:]]*[0-9]+/)) {s=substr($0, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); print s; exit}} END{if (NR==0) print 0}'
}

TEST_BRANCH="test-validation"
TEST_SLUG="test-adr-validation"

# Cleanup any stale test branch
if omnigraph branch list --json | grep -q "\"$TEST_BRANCH\""; then
  omnigraph branch delete "$TEST_BRANCH" --json >/dev/null || true
fi

MAIN_ROWS="$(read_main | count_rows)"

omnigraph branch create --from main "$TEST_BRANCH" --json >/dev/null

# Test all new mutation queries (the 5 new edge types)
omnigraph change \
  --query mutations/decisions.gq \
  --name insert_supersedes \
  --params '{"from_slug":"test-a","to_slug":"test-b"}' \
  --branch "$TEST_BRANCH" \
  --json >/dev/null

omnigraph change \
  --query mutations/decisions.gq \
  --name insert_depends_on_decision \
  --params '{"from_slug":"test-b","to_slug":"test-a"}' \
  --branch "$TEST_BRANCH" \
  --json >/dev/null

omnigraph change \
  --query mutations/decisions.gq \
  --name insert_refines \
  --params '{"from_slug":"test-c","to_slug":"test-a"}' \
  --branch "$TEST_BRANCH" \
  --json >/dev/null

omnigraph change \
  --query mutations/decisions.gq \
  --name insert_implements \
  --params '{"from_slug":"test-d","to_slug":"test-c"}' \
  --branch "$TEST_BRANCH" \
  --json >/dev/null

omnigraph change \
  --query mutations/decisions.gq \
  --name insert_conflicts_with \
  --params '{"from_slug":"test-e","to_slug":"test-a"}' \
  --branch "$TEST_BRANCH" \
  --json >/dev/null

# Verify new read queries return expected results
SUPERSEDED="$(omnigraph read --query queries/decisions.gq --name decisions_superseded_by --branch "$TEST_BRANCH" --params '{"slug":"test-a"}' --json | count_rows)"
if [[ "${SUPERSEDED:-0}" -ne 1 ]]; then
  echo "expected decisions_superseded_by to return 1 row" >&2
  exit 1
fi

DEPENDING="$(omnigraph read --query queries/decisions.gq --name decisions_depending_on --branch "$TEST_BRANCH" --params '{"slug":"test-a"}' --json | count_rows)"
if [[ "${DEPENDING:-0}" -ne 1 ]]; then
  echo "expected decisions_depending_on to return 1" >&2
  exit 1
fi

DEPENDED_ON="$(omnigraph read --query queries/decisions.gq --name decisions_depended_on_by --branch "$TEST_BRANCH" --params '{"slug":"test-b"}' --json | count_rows)"
if [[ "${DEPENDED_ON:-0}" -ne 1 ]]; then
  echo "expected decisions_depended_on_by to return 1" >&2
  exit 1
fi

# Also test the existing insert_decision still works
omnigraph change \
  --query mutations/decisions.gq \
  --name insert_decision \
  --params '{"slug":"'"$TEST_SLUG"'","title":"Validation Decision","rationale":"Inserted by validate.sh","status":"proposed","date":"2026-04-23"}' \
  --branch "$TEST_BRANCH" \
  --json >/dev/null

BRANCH_ROWS="$(omnigraph read --query queries/decisions.gq --name list_decisions --branch "$TEST_BRANCH" --json | count_rows)"
EXPECTED=$((MAIN_ROWS + 1 + 5))  # 5 test decisions inserted for edge tests
if [[ "${BRANCH_ROWS:-0}" -lt ${EXPECTED:-0} ]]; then
  echo "expected branch decision count to increase" >&2
  exit 1
fi

omnigraph branch merge "$TEST_BRANCH" --into main --json >/dev/null
MERGED_ROWS="$(read_main | count_rows)"
if [[ "${MERGED_ROWS:-0}" -lt ${EXPECTED:-0} ]]; then
  echo "expected merged decision count to increase on main" >&2
  exit 1
fi

omnigraph branch delete "$TEST_BRANCH" --json >/dev/null

echo "omnigraph validate: OK"
