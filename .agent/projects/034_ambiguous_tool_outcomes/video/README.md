# Effect disclosure for tool faults — video explainer

`effect-disclosure-explainer.mp4` is a 4 min 11 s explainer, in the style of a 3Blue1Brown video,
of the capabilities `../ADR-001-effect-disclosure-for-tool-faults.md` would enable. 1920×1080,
30 fps, H.264 with mono AAC, 17.8 MB. It is **narrated by a synthetic voice**, and every spoken
line is also on screen as a caption.

It is an experiment, made on 2026-10-03 with Manim Community 0.20.1 and the Kokoro v1.0 speech
model. `explainer.py` holds the eight scenes, one per beat. Everything else — the scene kit, the
narration, the render and its checks — is `tools/explainer`, which was extracted from this folder.

Like the diagrams in `../mmd/`, it is **dated evidence**. The ADR is Proposed: the operator has
ruled on nothing, and none of what the video shows exists at HEAD. The last scene says so.

## What it shows

| Scene | Length | What it shows | Source |
|---|---|---|---|
| `S1_Hook` | 34 s | A refund that landed, was reported failed, and was retried: the fault Havoc measured as destructive in 12 of 12 runs. | note, header |
| `S2_Today` | 25 s | Probe cases A and B side by side: a command that never started and one that exited 0 both come back as `exit_code: 1`, empty `stdout`; only the `stderr` prose differs. | ADR §0, D2 |
| `S3_Line` | 47 s | One line, "the effect is entered". Faults seen before it render `none`, the rest `unknown`. `SpawnFailed` moves from left to right; `NotAllowed` and `PermissionDenied` arrive dashed; a third value is struck out. | ADR D1, D2, §5 |
| `S4_Read` | 28 s | Capability 1: the `fault` object appears inside a faulted result, with what each field means, why it comes first, and what the model can now decide with. | ADR D3 |
| `S5_Partial` | 22 s | Capability 2: the same command today (`Err(Timeout(7005))`, output gone) and under `timeout -k 1 2` (exit 124, output intact). Both stay `unknown`. | note §6.1 cases 3, 5; ADR D6 |
| `S6_World` | 27 s | Capability 3: two runs that differ only in `applied`; the same `ToolFailed` crosses to the harness in both. Then the catalogue gains two world-only rows, each the twin of a wire row. | ADR D4 |
| `S7_Props` | 48 s | Capability 4: P1 as a 2×2 of what the model is told against what the world did; P2 as a pair of traces that must be identical; P3 as one call id served once. Each with its mutation going red. | ADR §2 |
| `S8_Recap` | 21 s | The five phases in order with the upstream asks alongside, then a PROPOSED stamp. | ADR §4, §6 |

Each scene carries its sources in small type at the bottom left of the frame.

## What is illustrative, not measured

- **The refund story** is Havoc's scenario as the note retells it. Motoko has no refund tool.
- **The result cards in `S2_Today`** are what `run_process_result` builds, read from
  `tool_runtime.ail:920–930` and `:1012–1019`. The probes call `std/process.exec` directly and do
  not read the message the model gets; the ADR says the same of its own table.
- **The JSON in `S4_Read`** is D3's example without its `truncated` field.
- **The wrapper in `S5_Partial`** is measured by direct probe only. Phase 0b still needs its own
  probe through `run_process_result`, and the frame says so.
- **`call_7`, the twelve trace cells and the unlabelled catalogue rows** are placeholders. The
  counts that are real are eleven rows becoming thirteen.
- **"retry?" and "check first?"** are not a claim about what a model does. Measuring that is out
  of scope for the ADR (§3).

## The voice

Each caption is spoken by Kokoro v1.0 (open weights, Apache-2.0, runs on CPU), voice `af_heart`:
38 clips, 166 s of speech. Nothing leaves the machine. How clips are made, timed and mixed is in
`tools/explainer/README.md`; what is particular to this film is the `SAY` table at the top of
`explainer.py`, which respells a few terms for the voice (`exit_code: 1` is said "exit code one",
`65,536` in words, `P1` "P one"). The captions are unchanged.

What was checked, since the voice was never listened to while making it:

| Check | Result |
|---|---|
| Whisper `small.en` transcription of each clip against its line | 28 of 38 word for word. The other ten differ only by homophones (write/right, prose/pros, red/read, catalogue/catalog) or by digits for spelt-out numbers. No wrong or missing word. |
| Where speech starts in the final file against the scenes' timelines | all 38 within 25 ms |
| Clips overlapping | none |
| Loudness of the final track | -17.3 LUFS integrated, peak -0.9 dBFS |
| Geometry lint | no findings |

A transcription round trip shows the words are intelligible and correct. It does not show that
the delivery sounds natural, or that a stress or a pause falls where a narrator would put it.

## Re-render

```sh
tools/explainer/setup.sh                  # once: Manim, ffmpeg and Kokoro, about 1.5 GB, no root
cd .agent/projects/034_ambiguous_tool_outcomes/video
../../../../tools/explainer/explainer lint explainer.py             # 27 s, draws nothing
../../../../tools/explainer/explainer render explainer.py           # 2.5 min, writes the mp4 here
../../../../tools/explainer/explainer render explainer.py --draft   # a 480p preview in scratch
```

The first render also synthesizes the 38 clips, which takes about three and a half minutes;
after that only changed captions are re-made. `--no-voice` renders captions only and
`--transcribe` repeats the Whisper check. See `tools/explainer/README.md` for the rest.

## Notes on the source

- **Colour is meaning**: green `none`, yellow `unknown`, teal what only the world knows, blue the
  harness, red a fault or a mutation, gold the retry and the stamp.
- **Caption timing is computed, not hand-tuned**: a scene waits until its caption has been up for
  one second plus one for every sixteen characters, or until its clip has ended, whichever is
  later.
- **The film through the tool is the film as first made.** The render from `tools/explainer`
  matches the hand-built pipeline's last output on every one of 7,534 frames and every audio
  sample.
