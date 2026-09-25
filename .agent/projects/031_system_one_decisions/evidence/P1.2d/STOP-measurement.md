# P1.2d — stopped (2nd): per-call decoding is not cheap against a hook's cost

PLAN-001 (031) §3 P1.2, batch D, resumed under Amendment 3 at HEAD `f21e508d`. AILANG v0.33.0. This is the
brief's measurement exit: *a measurement the ADR's sentence does not survive — stop and report the
numbers*. The sentence is ADR D2 "Cost": per-call decoding is expected to be "cheap against a hook's
cost". **Nothing is committed.** The migration is complete in the working tree (see the last section).

## The numbers (`bench/SUMMARY.txt`, raw in `bench/RAW.txt`)

Method (`bench/bench.sh 3`). BEFORE is a lock-free workspace from `git archive 181051d0`, with the 7.4
ABI and compose/herdr/ai-compat as of that commit. The two packages are byte-identical to HEAD before
P1.2d. AFTER uses HEAD's ABI 8.0 plus P1.2d's compose and herdr. Each hook is invoked the way its host
invokes it:
- 7.4: the registered closure on the full `ExtCtx`.
- 8.0: the registered named payload on its view, with the registration's `config` stamped as
  `ext_config`.

The inputs are the same synthetic ones in both versions (ports are no-ops and never reached on these
paths). Each sample is one timed batch of 400 calls on the ms clock. There are 15 samples per run and
3 interleaved rounds (7.4, 8.0, 7.4, …), so **n = 45 per cell**. Figures are per call in µs. The
8-core machine was shared with other delegates (load 3–5), which is where the long max tails come from.

| case | 7.4 median | 8.0 median | Δ | 7.4 min–max | 8.0 min–max |
|---|---:|---:|---:|---|---|
| compose interceptor, default mode (`subagent`: the path taken on every response) | 12.5 | 120.0 | **+107.5 (×9.6)** | 10.0–135.0 | 57.5–327.5 |
| compose interceptor, `inline`, ~2 KB response with no fence | 15.0 | 155.0 | **+140.0 (×10.3)** | 12.5–130.0 | 70.0–472.5 |
| herdr prompt shaper, orchestrator off (every configuration outside an orchestrator pane) | 10.0 | 42.5 | **+32.5 (×4.3)** | 7.5–132.5 | 30.0–140.0 |
| herdr prompt shaper, orchestrator on, two run files | 160.0 | 335.0 | **+175.0 (×2.1)** | 75.0–297.5 | 237.5–680.0 |
| *control:* compose interceptor body only, values passed in | 12.5 | 12.5 | +0.0 | 10.0–107.5 | 10.0–95.0 |
| *control:* herdr `prompt_patch` body only | 150.0 | 160.0 | +10.0 (noise) | 72.5–327.5 | 75.0–272.5 |

**Retained `config`** (canonical encoded JSON): compose **610 B**; herdr **619 B** (orchestrator off)
and **672 B** (on, two run files).

## What the numbers say

- **The views cost nothing.** The body-only controls are identical across versions. The extra time is
  entirely the payload decoding its registration values from `ext_config` on every call: a few
  `std/json` lookups and one small record rebuilt.
- **Against the hook, decoding is not cheap.** On the two paths that run on every step in the default
  configuration, decoding costs **3–9× the hook body itself** (compose +107.5 µs over 12.5 µs; herdr
  +32.5 µs over 10 µs). Even the richest case measured (herdr orchestrator on) doubles the hook.
  Rewriting the decodes to be lazy would not change this class. herdr's off case already decodes the
  minimum: one nested `get` and one `getBool`. That alone is 3× the body. The cost is the pin's
  interpreted JSON access, not the amount decoded.
- **Against a step, it is negligible.** The largest per-call figure, 335 µs (tail 680 µs), is well under
  a millisecond per model response. A step's model call takes seconds, so this is below 0.1%.
- The retained size is small, about 0.6 KB per extension, and does not change the picture.

## For the orchestrator (an amendment either way)

The expectation fails as worded ("a hook's cost") and holds against the step. Possible amendments:
- **(a)** restate the expectation against the step or dispatch cost, with these numbers attached, and
  keep per-call decoding;
- **(b)** keep the claim and have the host hand each atom a **decoded, typed** value. That is a
  contract change (a typed config position or a per-extension decode hook), so it is 9.0 under the
  8.x rule;
- **(c)** accept the cost for these two extensions and record it.

## State of P1.2d in the working tree (all uncommitted, own paths only)

- **Packages.** `motoko-ext-compose` (`compose.ail`, `config.ail`, `register.ail`, `ailang.toml`) and
  `motoko-ext-herdr` (`herdr.ail`, `orchestrator.ail`, `register.ail`, `ailang.toml`). All 10 sites are
  named. `register_with_config` returns `{ config, caps }` with `caps` delegated to `compose_caps()` or
  `herdr_caps(tools, exit_enabled)`. Config is encoded once and decoded per call. The views are applied.
  compose's three `ExtPorts` helpers now take `SnippetExecPorts{tool_handle}` and
  `RemovePorts{path_stat, file_remove}`. ABI is pinned to 8.0.
- **Exit 1, own root** (`p12d_pkgroot.sh`): both clean. Ceilings added: compose `Rand`, `Trace` (`Rand`
  was already over the ceiling at 7.4, `own_root_at_181051d0.log`); herdr `AI`, `Net`, `SharedMem`,
  `Stream`, `Rand`, `Trace`. Dropping any one of the 8 fails the check, naming that effect.
- **Exit 2, own tests** (`p12d_ws.sh test`): compose `config.ail` 2/2 (the new round-trip); herdr
  `herdr.ail` 8/8, `orchestrator.ail` 90/90, `dagr.ail` 73/73, `types.ail` 282/282.
- **Exit 3, gate:** compose and herdr `config-caps pass`. On the working tree (which includes other
  batches' uncommitted edits) the tree reads **pass 18 of 18, binding rejections 0**.
- **Exit 4, masked files** (`p12d_core_check.sh`, committed HEAD plus P1.2d's paths only): **10/11
  check**. `declared_vs_performed.ail` is migrated but cannot check until batches B and C land, because
  it imports all 18 extensions and scratchpad is still 7.4 at HEAD.
- **Not run yet:** the masked files' runs, and mutgate.
