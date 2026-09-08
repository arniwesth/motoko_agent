# Measurements: which herdr failure codes mean "the agent is gone"

Date: 2026-08-31. herdr at `/usr/local/bin/herdr`, live session `w5`, probed from inside a pane.
Answers `DESIGN-dagr-as-delegation-view.md` §8 item 5: the `lost` row of the dagr producer must
not bury transient herdr errors as dead attempts, so "pane gone" needed measuring against
"herdr unwell" before being wired.

## Method

Five cases, each driven with real CLI calls; exit code and the stderr envelope's `error.code`
recorded. Streams were captured separately after an artifact in the first pass: `$?` after a
`… | head` pipeline reports `head`'s exit, which produced a phantom "error with exit 0" for the
`--session` flavor. Clean reruns show no such case.

## Results

| case | how staged | command | exit | `error.code` |
|---|---|---|---|---|
| A. agent name never existed | none | `agent get` / `agent wait --timeout 2000` | 1 | `agent_not_found` (both) |
| B. pane id never existed | none | `agent get w9:p99` | 1 | `agent_not_found` |
| C. agent existed, pane then closed | `pane split` → `agent start mot131probe --kind claude` (verified `idle`) → `pane close` | `agent get` / `agent wait` by name; `agent get` by old pane id | 1 | `agent_not_found` (all three) |
| D. server unreachable, socket flavor | `HERDR_SOCKET_PATH=/tmp/no-such-herdr.sock` | `agent get` / `agent wait` | 1 | `server_not_running` |
| E. server unreachable, session flavor | `herdr --session no-such-session-xyz` | `agent get` | 1 | `server_not_running` |

All errors arrive as JSON on **stderr**, `failure_shape` bucket `herdr_json`; stdout is empty.
The `timeout` code (a wait interval elapsing, `wait_elapsed`) and `cli_syntax` (exit 2) were
already pinned by `types.ail`'s test vectors and are unchanged.

## Conclusion for the producer

- **`agent_not_found` ⇔ the agent is gone.** herdr does not distinguish "never existed" from
  "existed and its pane closed" (A ≡ C); for the producer that distinction does not matter —
  either way there is nothing left to observe, and with the MOT-131 early answer-file read in
  place, reaching this code means there is also no answer. Map it to attempt `lost` → task
  `failed`, from **both** `agent wait` and `agent get`.
- **`server_not_running` ⇔ herdr is unwell.** The agent's pane may be perfectly alive behind an
  unreachable API socket. Write **nothing** to the run file; surface the error to the model.
- **Everything else** (`timeout` excepted, which is the working branch) is unclassified: write
  nothing. The enumeration above is not exhaustive — a code not seen here is by definition not
  evidence the agent is gone.

## Not measured

- An agent that **exits inside a live pane** (released/replaced rather than pane-closed). Staging
  it reliably needs an agent that quits on cue; expected to surface as `agent_not_found` once
  herdr clears the name, but that is expectation, not measurement.
- Server crash **mid-call** (connection dropped after accept), as opposed to refused up front.
