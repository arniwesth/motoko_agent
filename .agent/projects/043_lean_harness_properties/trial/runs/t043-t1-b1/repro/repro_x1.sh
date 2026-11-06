#!/usr/bin/env bash
# repro/repro_x1.sh — step (4) for X-1: one TUI environment, through the REAL path between copies.
#
#   bash ../out/repro/repro_x1.sh <HERDR_ENV> <HERDR_BIN_PATH> <HERDR_PANE_ID>     (from the tree root)
#
# Each argument is a string, or the word UNSET. With every ambient HERDR_* removed and those three
# set in the TUI's process.env:
#   * the TUI copy is the REAL readHerdrEnvironment(process.env)  (herdr-agent-state.ts:157);
#   * the runtime's environment is the REAL buildChildEnv(...)    (runtime-process.ts:499, :629-633);
#   * the runtime copy is the REAL register_with_config           (register.ail:43-207) run by ailang
#     in exactly that HERDR_* environment (plus PATH, HOME, MOTOKO_WORKDIR, HERDR_ORCHESTRATOR=off);
#     it is open when it advertises tools.
# Nothing in the tree is modified (buildChildEnv's mkdir lands in a temp workdir).
#
# Exit 1 when the TUI reports to herdr and the extension does not advertise tools, or the other
# way round (X-1 violated); 0 when they agree; 2 on a harness failure. Env: REPO (default: cwd).
set -uo pipefail
[[ $# -eq 3 ]] || { echo "usage: $0 <HERDR_ENV> <HERDR_BIN_PATH> <HERDR_PANE_ID> (UNSET for unset)"; exit 2; }
repo="$(cd "${REPO:-.}" && pwd)"
[[ -f "$repo/src/tui/src/runtime-process.ts" ]] || { echo "run from the tree root (or set REPO)"; exit 2; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/pkg" "$tmp/wd"

cat > "$tmp/pkg/ailang.toml" <<TOML
[package]
name = "local/herdr_gate_repro"
version = "0.1.0"
edition = "1"
[dependencies]
"sunholo/motoko_ext_herdr" = { path = "$repo/packages/motoko-ext-herdr" }
TOML
cat > "$tmp/pkg/register_gate.ail" <<'AIL'
module register_gate
import std/io (println)
import std/string (join)
import pkg/sunholo/motoko_ext_herdr/register (register_with_config)
import pkg/sunholo/motoko_ext_herdr/herdr (herdr_tools_of)
export func main() -> () ! {Clock, Env, FS, IO, Process} {
  let r = register_with_config(());
  println("tools=${join(",", herdr_tools_of(r.config))}")
}
AIL
( cd "$tmp/pkg" && ailang lock >/dev/null 2>&1 ) || { echo "ailang lock failed"; exit 2; }

REPRO_ARGS="$(printf '%s\0%s\0%s' "$1" "$2" "$3" | base64 -w0)" bun -e '
  const [repo, tmp] = process.argv.slice(1);
  const { readHerdrEnvironment } = await import(repo + "/src/tui/src/herdr-agent-state.ts");
  const { buildChildEnv } = await import(repo + "/src/tui/src/runtime-process.ts");
  const vals = Buffer.from(process.env.REPRO_ARGS, "base64").toString("utf8").split("\0");
  const names = ["HERDR_ENV", "HERDR_BIN_PATH", "HERDR_PANE_ID"];
  for (const k of Object.keys(process.env)) if (k.startsWith("HERDR_")) delete process.env[k];
  names.forEach((n, i) => { if (vals[i] !== "UNSET") process.env[n] = vals[i]; });
  const tui = readHerdrEnvironment(process.env);
  const child = buildChildEnv(tmp + "/wd", "default", "", "");
  const fwd = {};
  for (const [k, v] of Object.entries(child)) if (k.startsWith("HERDR_") && v !== undefined) fwd[k] = v;
  const p = Bun.spawnSync(
    ["ailang", "run", "--relax-modules", "--caps", "Clock,Env,FS,IO,Process", "--entry", "main", "register_gate.ail"],
    { cwd: tmp + "/pkg", env: { PATH: process.env.PATH, HOME: process.env.HOME, MOTOKO_WORKDIR: tmp + "/wd",
                                HERDR_ORCHESTRATOR: "off", ...fwd } });
  const m = p.stdout.toString().match(/^tools=(.*)$/m);
  if (!m) { console.log("ailang run failed: " + p.stderr.toString().slice(0, 400)); process.exit(2); }
  const open = m[1] !== "";
  console.log("input (TUI process.env): " + names.map((n, i) => n + "=" + (vals[i] === "UNSET" ? "<unset>" : JSON.stringify(vals[i]))).join(" "));
  console.log("  TUI readHerdrEnvironment          -> " + JSON.stringify(tui));
  console.log("  buildChildEnv forwards            -> " + JSON.stringify(fwd));
  console.log("  runtime register_with_config tools -> [" + m[1] + "]");
  if ((tui !== null) !== open) {
    console.log("X-1 VIOLATED: the TUI " + (tui ? "reports to herdr" : "does not report to herdr") +
                " and the extension " + (open ? "advertises" : "does not advertise") + " its tools");
    process.exit(1);
  }
  console.log("X-1 holds on this input");
  process.exit(0);
' "$repo" "$tmp"
