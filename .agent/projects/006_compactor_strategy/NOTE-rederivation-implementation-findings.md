# Re-derivation implementation findings

**Status:** Engine A and WS4a implemented; WS3 and live measurement remain.

## As built

- Engine A stores a rolling summary with an absolute `boundary_marker` in the existing
  `artifacts.compaction_ai` object. Every cache hit reconstructs the contiguous tail from that marker;
  overflow folds only the oldest part of that tail and advances the marker.
- `keep_recent_tokens` is opt-in for compatibility. The qwen36 live profile uses 20,000 tokens. Profiles
  without the field retain the legacy message-count split.
- The structured summary/update prompts preserve the plan's sections and cumulative file-operation line.
- Structural compaction caps a single tool result at 30% of the context limit when the pending window is
  already above target. Small results and low-pressure windows pass unchanged.
- Structural `Compacted` decisions preserve incoming artifacts instead of replacing them with `{}`.

## Verification

- `make compaction_dst`: pass.
- `make conformance`: pass.
- `AILANG_RELAX_MODULES=1 ailang test packages/motoko-ext-compaction-ai/compaction_ai.ail`: pass.
- `MOTOKO_CONFIG=hunyuan3-free-compaction-live make verify_extensions`: pass.

## Residual

- The hunyuan live profile has the 20,000-token setting in the working tree, combined with pre-existing
  profile edits, and was deliberately not included in the implementation commits.
- No several-hundred-step or live provider run was performed. Engine A drift is therefore unmeasured;
  Engine B remains gated and was not built.
- WS3's FS-backed `EvidenceAdd` / `EvidenceGet` / `EvidenceList` store and post-fold pointer bridge are not
  implemented. The issue must remain in progress.
- Live qwen36 and hunyuan compaction-heavy corroboration remains to be run.
