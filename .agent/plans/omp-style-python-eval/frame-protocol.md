# Eval Frame Protocol

This contract is transport-neutral. Design C resolves loopback frames locally in
the env-server; Design B' forwards the same frames to the brain over WebSocket.

## Cell-Run Frames

These frames flow between the env-server kernel host and one language-specific
kernel over NDJSON. The language is selected by the `/exec-cell` request, not by
the frame.

- `run {id, code, silent?, cwd?, env?}`
- `started {id}`
- `stdout {id, text}`
- `stderr {id, text}`
- `display {id, bundle}`
- `result {id, bundle}`
- `error {id, ename, evalue, traceback}`
- `done {id, status, executionCount, cancelled}`

`bundle` is a MIME-oriented display bundle:

```json
{
  "type": "json|image|markdown|status|text",
  "mime": "application/json",
  "data": {},
  "width": 0,
  "height": 0
}
```

## Loopback Frames

These frames flow from a running cell to the resolver.

- `tool-request {reqId, tool, arguments}`
- `tool-result {reqId, exit_code, stdout, stderr, metadata}`

Design C resolves `tool-request` in the env-server against the fixed allowlist
`read`, `write`, `append`, `search`, and `agent`. Design B' forwards the same
shape to the brain.
