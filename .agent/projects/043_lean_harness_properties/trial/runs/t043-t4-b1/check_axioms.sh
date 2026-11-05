#!/usr/bin/env bash
# check_axioms.sh — run Lean 4.28.0 on ChainModel.lean, write axioms.txt, and fail unless
#   * Lean reports no error,
#   * every `theorem` in the file has a `#print axioms` line,
#   * no theorem depends on anything beyond propext, Classical.choice, Quot.sound
#     (so no sorryAx, and no Lean.ofReduceBool, which native_decide would introduce),
#   * the source has no `sorry` / `native_decide` token outside backquoted prose.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
LEAN="${LEAN:-$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin/lean}"
"$LEAN" --version > "$here/axioms.txt"
"$LEAN" "$here/ChainModel.lean" > "$here/.lean_check.out" 2>&1 || { cat "$here/.lean_check.out"; echo "LEAN ERROR"; exit 1; }
grep -E "depends on axioms|does not depend on any axioms" "$here/.lean_check.out" >> "$here/axioms.txt"
grep -E "warning|error" "$here/.lean_check.out" | sed 's|^|# lean: |' >> "$here/axioms.txt" || true
thms=$(grep -cE '^theorem ' "$here/ChainModel.lean")
printed=$(grep -cE "depends on axioms|does not depend on any axioms" "$here/.lean_check.out")
bad=$(grep -E "depends on axioms" "$here/.lean_check.out" | sed -E 's/.*\[(.*)\]/\1/' | tr ',' '\n' | tr -d ' ' \
      | grep -vE '^(propext|Classical\.choice|Quot\.sound)$' | sort -u || true)
src=$(grep -nE '(^|[^`])\b(sorry|native_decide)\b' "$here/ChainModel.lean" || true)
echo "theorems: $thms; axiom lines: $printed; non-standard axioms: ${bad:-none}; sorry/native_decide in source: ${src:-none}"
[[ "$thms" -eq "$printed" && -z "$bad" && -z "$src" ]]
