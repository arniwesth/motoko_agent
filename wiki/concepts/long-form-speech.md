---
sources: [summaries/Markdown_to_Audio_Qwen3_TTS_Implementation_Plan.md]
brief: Techniques and strategies to generate stable, natural speech for texts exceeding 10 minutes.
---

# Long‑Form Speech Synthesis

## Overview
Long‑form speech synthesis is the generation of continuous, intelligible, and natural‑sounding spoken audio from extended text inputs – typically more than 10 minutes of speech. The primary use case targeted in this project is converting entire Markdown documents into audiobook‑style narration, as described in the [[summaries/Markdown_to_Audio_Qwen3_TTS_Implementation_Plan|implementation plan]].

Succeeding at long‑form synthesis requires overcoming challenges that short‑utterance TTS does not face: maintaining prosodic coherence across sentence boundaries, managing memory and latency for very large inputs, avoiding quality degradation over time, and handling the acoustic consequences of concatenating many individually synthesised chunks.

## Core Challenges
- **Temporal drift** – Individual samples can accumulate small timing/intonation errors that become perceptible over minutes.
- **Co‑reference and prosody** – Natural speech expects consistent pitch contour, speaking rate, and emphasis across paragraphs; per‑chunk synthesis can break these.
- **Memory pressure** – Processing an entire long‑form text at once with large models is often infeasible on consumer hardware.
- **Silence placement** – Synthesised speech lacks natural conversational pauses unless explicitly inserted.

## Qwen3‑TTS Approach
The [[concepts/qwen3-tts|Qwen3‑TTS]] model family provides explicit support for long‑form narration:
- The **12 Hz** track is reported to maintain stable quality over >10 minute samples in the official technical report (grounded in [[papers/Qwen3_TTS]]).
- The `longform` profile in the `md2audio` tool selects the 1.7 billion‑parameter 12 Hz model as the default, optimised for high‑quality narration.
- Long inputs are broken into **chunks** (paragraph‑ or sentence‑aligned, with a character budget) via the [[concepts/chunking-for-synthesis|chunking engine]], and each chunk is synthesised independently.  
- Fixed silences are inserted between chunks to mimic natural paragraph breaks (configurable via `--pause-ms`).
- Chunk‑by‑chunk synthesis keeps memory usage bounded, and an optional **streamed concat** mode further reduces peak memory for very large documents.
- The [[concepts/markdown-narration-rules|markdown narration rules]] strip non‑vocal content (code blocks, images) to keep the spoken text narrative‑oriented.

## Relation to Other Concepts
- [[concepts/qwen3-tts]] – The model family providing two tracks (12 Hz, 25 Hz) with different long‑form trade‑offs.
- [[concepts/chunking-for-synthesis]] – Deterministic segmentation that enables long‑form conversion without dropping text.
- [[concepts/markdown-narration-rules]] – How source markdown is normalised into narratable form.
- [[concepts/tts-backends]] – Future backends will also need long‑form strategies; this concept guides their design.
- [[summaries/Markdown_to_Audio_Qwen3_TTS_Implementation_Plan]] – The full plan detailing how long‑form synthesis is implemented in the `md2audio` tool.

## Practical Guidelines
For long‑form jobs:
- Use the `longform` profile (`--profile longform`) to select a model optimised for stability.
- Increase `--pause-ms` to 500–700 ms for audiobook‑style narration.
- Ensure sufficient disk space for intermediate chunk files when using `--keep-chunks` for debugging.
- On memory‑constrained environments, prefer the 0.6 B variant with manageable chunk sizes.