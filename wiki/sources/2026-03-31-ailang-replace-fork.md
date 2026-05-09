# Replace ailang/ with arniwesth/ailang fork

**Date:** 2026-03-31

## What was done

Replaced the `ailang/` directory (previously cloned from `https://github.com/sunholo-data/ailang.git`) with the fork at `https://github.com/arniwesth/ailang.git`, then reapplied the required runtime patches.

## Steps

1. **Saved patch context** — confirmed the two modified Go files in the old clone matched the patch specs in `runtime-patches/`.

2. **Removed old clone** — deleted `ailang/` (sunholo-data origin).

3. **Cloned the fork**:
   ```
   git clone https://github.com/arniwesth/ailang.git ailang
   ```

4. **Reapplied runtime patch to `internal/effects/io.go`**:
   - Added `RegisterOp("IO", "pollStdin", ioPollStdin)` inside `init()`, after the existing `readLine` registration.
   - Added the full `ioPollStdin` function (non-blocking stdin peek via `bufio.Reader.Buffered()`).

5. **Reapplied runtime patch to `internal/builtins/io.go`**:
   - Added the `_io_poll_stdin` builtin registration inside `registerIO()`, after the `_io_readLine` block.
   - Used variable names `implPollStdin`/`typePollStdin` (the fork already uses `impl5`/`type5` for the `_io_exit` builtin added since the original).

6. **Built and installed**:
   ```
   go build ./cmd/ailang
   go install ./cmd/ailang
   ```

7. **Verified**: `_io_poll_stdin(())` returns `""` when no input is buffered.

## Notes

- The fork (`arniwesth/ailang`) is ahead of `sunholo-data/ailang` — it includes additional builtins (`_io_exit`) and other changes not present in the original.
- The stdlib in the fork carries version tag `v0.10.0` while the dev binary reports `dev`, producing a harmless version mismatch warning at runtime.
- Only the Go source patches from `runtime-patches/` were reapplied. The prompt markdown and test file changes from the old clone were not carried over (they were not Go code and not referenced by `runtime-patches/`).
