#!/usr/bin/env bash
# repro/repro_p11.sh — step (4) for P1.1: one input, both REAL copies, compared.
#
#   bash ../out/repro/repro_p11.sh <HERDR_ENV> <HERDR_BIN_PATH> <HERDR_PANE_ID>     (from the tree root)
#
# Each argument is a string, or the word UNSET. The TypeScript copy, readHerdrEnvironment
# (src/tui/src/herdr-agent-state.ts:157), gets an env object with the set ones; the AILANG copy,
# herdr_env_ready (packages/motoko-ext-herdr/types.ail:1425), is called with the three strings,
# UNSET passed as "" (P1.1). Nothing in the tree is modified: the AILANG call goes through a
# throw-away package in a temp dir that depends on the tree's motoko-ext-herdr by path.
#
# Exit 1 when the two copies disagree (P1.1 violated on this input), 0 when they agree, 2 on a
# harness failure. Env: REPO (default: the current directory).
set -uo pipefail
[[ $# -eq 3 ]] || { echo "usage: $0 <HERDR_ENV> <HERDR_BIN_PATH> <HERDR_PANE_ID> (UNSET for unset)"; exit 2; }
repo="$(cd "${REPO:-.}" && pwd)"
[[ -f "$repo/src/tui/src/herdr-agent-state.ts" ]] || { echo "run from the tree root (or set REPO)"; exit 2; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ts=$(REPRO_ARGS="$(printf '%s\0%s\0%s' "$1" "$2" "$3" | base64 -w0)" bun -e '
  const { readHerdrEnvironment } = await import(process.argv[1] + "/src/tui/src/herdr-agent-state.ts");
  const [e, b, p] = Buffer.from(process.env.REPRO_ARGS, "base64").toString("utf8").split("\0");
  const env = {};
  if (e !== "UNSET") env.HERDR_ENV = e;
  if (b !== "UNSET") env.HERDR_BIN_PATH = b;
  if (p !== "UNSET") env.HERDR_PANE_ID = p;
  console.log(JSON.stringify(readHerdrEnvironment(env)));
' "$repo") || { echo "bun failed"; exit 2; }

cat > "$tmp/ailang.toml" <<TOML
[package]
name = "local/herdr_gate_repro"
version = "0.1.0"
edition = "1"
[dependencies]
"sunholo/motoko_ext_herdr" = { path = "$repo/packages/motoko-ext-herdr" }
TOML
cat > "$tmp/gate_call.ail" <<'AIL'
module gate_call
import std/io (println)
import std/env (getEnvOr)
import pkg/sunholo/motoko_ext_herdr/types (herdr_env_ready)
export func main() -> () ! {Env, IO} {
  let r = herdr_env_ready(getEnvOr("GATE_E", ""), getEnvOr("GATE_B", ""), getEnvOr("GATE_P", ""));
  println(if r then "ready=true" else "ready=false")
}
AIL
u() { [[ "$1" == "UNSET" ]] && echo "" || echo "$1"; }
( cd "$tmp" && ailang lock >/dev/null 2>&1 ) || { echo "ailang lock failed"; exit 2; }
ail=$(cd "$tmp" && env -i PATH="$PATH" HOME="$HOME" GATE_E="$(u "$1")" GATE_B="$(u "$2")" GATE_P="$(u "$3")" \
      ailang run --relax-modules --caps Env,IO --entry main gate_call.ail 2>/dev/null | grep '^ready=') \
  || { echo "ailang run failed"; exit 2; }

printf 'input: HERDR_ENV=%q HERDR_BIN_PATH=%q HERDR_PANE_ID=%q\n' "$1" "$2" "$3"
echo "  readHerdrEnvironment -> $ts"
echo "  herdr_env_ready      -> ${ail#ready=}"
ts_open=$([[ "$ts" == "null" ]] && echo false || echo true)
if [[ "$ts_open" != "${ail#ready=}" ]]; then
  echo "P1.1 VIOLATED: the TypeScript gate is $([[ $ts_open == true ]] && echo non-null || echo null), herdr_env_ready is ${ail#ready=}"
  exit 1
fi
echo "P1.1 holds on this input"
exit 0
