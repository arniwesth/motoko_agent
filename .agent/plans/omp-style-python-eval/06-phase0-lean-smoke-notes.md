# Phase 0 smoke notes - Lean 4 eval REPL verification

Date: 2026-06-19. Recorded before implementation of plan 06.

## Toolchain / install facts

- `elan` was not installed initially. Installed with:
  `curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain leanprover/lean4:stable`
- Stable resolved to `leanprover/lean4:v4.31.0`.
  `lean --version`: `Lean (version 4.31.0, aarch64-unknown-linux-gnu, commit 68218e876d2a38b1985b8590fff244a83c321783, Release)`.
  `lake --version`: `Lake version 5.0.0-src+68218e8 (Lean version 4.31.0)`.
- Cloned `leanprover-community/repl` at `/tmp/lean-repl-smoke`.
- Current `repl` master pins `leanprover/lean4:v4.32.0-rc1` in `lean-toolchain`, so `lake build`
  installed that pinned toolchain and built the executable.
- REPL project layout:
  - `lean-toolchain`: `leanprover/lean4:v4.32.0-rc1`
  - `lakefile.toml`: `[[lean_exe]] name = "repl", root = "REPL.Main", supportInterpreter = true`
  - launch from the REPL checkout: `lake exe repl`
  - built binary: `/tmp/lean-repl-smoke/.lake/build/bin/repl`
- Cold build including pinned toolchain install: `55.117s`.
- Bare REPL warm one-shot launch (`#eval 1+1` through `lake exe repl`): about `0.28s`.

## JSON / framing facts

- Commands are newline-delimited JSON separated by a blank line.
- First command omits `env`; later commands use a numeric `env` from a previous response.
- Response shape observed:

```json
{"messages":[{"severity":"info","pos":{"line":1,"column":0},"endPos":{"line":1,"column":5},"data":"2"}],"env":0}
```

- `messages[].severity` values observed: `info`, `warning`, `error`.
- A command with no messages/sorries returns only `{"env": N}`.
- `#eval` output is an `info` message.

## Env threading

Input:

```json
{"cmd":"theorem smoke_add_comm (a b : Nat) : a + b = b + a := by omega"}

{"cmd":"theorem smoke_use : 2 + 3 = 3 + 2 := by simpa using smoke_add_comm 2 3", "env":0}

{"cmd":"theorem smoke_broken : 1 = 2 := by rfl", "env":1}
```

Output:

```json
{"env":0}

{"messages":[{"severity":"warning","data":"try 'simp' instead of 'simpa'\n\nNote: This linter can be disabled with `set_option linter.unnecessarySimpa false`"}],"env":1}

{"messages":[{"severity":"error","data":"Tactic `rfl` failed: The left-hand side\n  1\nis not definitionally equal to the right-hand side\n  2\n\n⊢ 1 = 2"}],"env":2}
```

Conclusion: a broken command still mints an env id (`2`). The commit gate must abandon that env on failure and leave `committedEnv` unchanged.

## Honesty signals

Clean theorem:

```json
{"cmd":"theorem clean_decide : (1 + 1 = 2) := by decide"}
{"cmd":"#print axioms clean_decide", "env":0}
```

Output:

```json
{"env":0}
{"messages":[{"severity":"info","data":"'clean_decide' does not depend on any axioms"}],"env":1}
```

Clean `omega` theorem:

```json
{"cmd":"#print axioms smoke_add_comm\n#print axioms smoke_use", "env":1}
```

Output:

```json
{"messages":[
  {"severity":"info","data":"'smoke_add_comm' depends on axioms: [propext, Quot.sound]"},
  {"severity":"info","data":"'smoke_use' depends on axioms: [propext]"}
],"env":3}
```

`sorry` theorem:

```json
{"cmd":"theorem sorry_thm : 1 = 2 := by sorry", "env":0}
{"cmd":"#print axioms sorry_thm", "env":2}
```

Output:

```json
{"sorries":[{"proofState":0,"pos":{"line":1,"column":32},"goal":"⊢ 1 = 2","endPos":{"line":1,"column":37}}],
 "messages":[{"severity":"warning","data":"declaration uses `sorry`"}],
 "env":2}
{"messages":[{"severity":"info","data":"'sorry_thm' depends on axioms: [sorryAx]"}],"env":3}
```

Exact sorry warning text uses backticks: `declaration uses `sorry``.
Both signals are present: `sorries[]` and `sorryAx`.

`native_decide` theorem:

```json
{"cmd":"theorem native_thm : (1000000 + 1 = 1000001) := by native_decide", "env":0}
{"cmd":"#print axioms native_thm", "env":4}
```

Output:

```json
{"env":4}
{"messages":[{"severity":"info","data":"'native_thm' depends on axioms: [native_thm._native.native_decide.ax_1]"}],"env":5}
```

The trust axiom name is theorem-specific, not `Lean.ofReduceBool` in this toolchain. Treat any non-standard axiom as `axiom_tainted`.

Custom axiom:

```json
{"cmd":"axiom customAx : False\ntheorem tainted_thm : False := customAx", "env":0}
{"cmd":"#print axioms tainted_thm", "env":6}
```

Output:

```json
{"env":6}
{"messages":[{"severity":"info","data":"'tainted_thm' depends on axioms: [customAx]"}],"env":7}
```

Allowed standard axiom set remains `{propext, Classical.choice, Quot.sound}`.

## Import / project layout facts

- `cmd` can contain multiple non-import declarations (`axiom ...\ntheorem ...` worked).
- `cmd` containing `import Std\ntheorem ...` failed with `unexpected identifier; expected command`.
- REPL README states imports are allowed only when no `env` is specified.
- Default MVP can use Lean/Std tactics like `omega` without an explicit import in the command.
- If project imports are needed, send an initial import command with no env and then thread that env.

Mathlib is a project dependency, not a runtime flag:

```toml
name = "LeanMathlibSmoke"
version = "0.1.0"
defaultTargets = ["LeanMathlibSmoke"]

[[lean_lib]]
name = "LeanMathlibSmoke"

[[require]]
name = "mathlib"
scope = "leanprover-community"
rev = "master"
```

with `lean-toolchain` pinned to `leanprover/lean4:v4.32.0-rc1`.
`lake update` cloned `leanprover-community/mathlib4` and dependencies, then downloaded 8571 cached artifacts.
Elapsed time: `128.785s`.

Mathlib launch command from the Mathlib project:

```sh
lake env /tmp/lean-repl-smoke/.lake/build/bin/repl
```

First Mathlib REPL run with `import Mathlib` then a theorem: `52.228s`.
Second warm run with `import Mathlib` then `#eval 1+1`: `6.454s`.

## `#eval` effect surface

`#eval` performs real IO in the spawned child.

File write:

```json
{"cmd":"#eval IO.FS.writeFile \"lean_eval_io_probe.txt\" \"hello from lean\"", "env":5}
```

Created `/tmp/lean-repl-smoke/lean_eval_io_probe.txt` with content `hello from lean`.

Process execution:

```json
{"cmd":"#eval IO.Process.run { cmd := \"pwd\", args := #[] }"}
{"cmd":"#eval IO.Process.run { cmd := \"sh\", args := #[\"-lc\", \"printf process-ok\"] }", "env":0}
```

Output included:

```json
{"messages":[{"severity":"info","data":"\"/tmp/lean-repl-smoke\\n\""}],"env":0}
{"messages":[{"severity":"info","data":"\"process-ok\""}],"env":1}
```

Network through subprocess is available without an external sandbox:

```json
{"cmd":"#eval IO.Process.run { cmd := \"sh\", args := #[\"-lc\", \"curl -Is --max-time 3 https://example.com | head -n 1\"] }"}
```

Output:

```json
{"messages":[{"severity":"info","data":"\"HTTP/2 200 \\x0d\\n\""}],"env":0}
```

Conclusion: Lean REPL must be treated at least as strictly as py/js. Lean itself does not enforce network/process confinement; the host must launch it under the same external confinement posture as other eval kernels.

## Phase 0 acceptance result

- Clean theorem by `omega` elaborates, has zero sorries, and only standard axioms.
- `sorry` is detected by both `sorries[]` and `#print axioms` (`sorryAx`).
- Cell 2 can reference a theorem from cell 1 via env threading.
- Failed elaboration still returns an env id, so non-committed envs must be abandoned.
- `#eval` performs file IO, process execution, and network-capable subprocesses unless externally sandboxed.
- Mathlib requires a separate Lake project and `lake env <repl-binary>` launch; it is not a per-command runtime flag.
