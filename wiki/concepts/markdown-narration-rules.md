---
sources: [summaries/Markdown_to_Audio_Qwen3_TTS_Implementation_Plan.md]
brief: Rules for converting Markdown elements to spoken narration, including headings, lists, links, code, and tables.
---

## Markdown Narration Rules

These rules define how a Markdown document is transformed into a plain‑text script suitable for speech synthesis. They are applied by the `md2audio` pipeline’s **[text normalization stage]([[summaries/Markdown_to_Audio_Qwen3_TTS_Implementation_Plan]])** before the text is split into chunks and passed to the [[concepts/qwen3-tts]] backend.

### Purpose
Raw Markdown is not directly speakable—structural markup, link URLs, and code blocks would confuse a TTS engine or produce unnatural prosody. The narration rules produce a clean, linear, spoken‑friendly version while preserving the intent of the original content.

### Rule Set (MVP)
Based on the implementation plan (Section 7), the following transformations are applied:

- **Headings** – Read as plain heading text, followed by a pause.
- **Paragraphs** – Kept as‑is, with punctuation cleanup.
- **Bullet lists** – Each item is prefixed with *“Bullet: ”*.
- **Numbered lists** – Each item is prefixed with *“Item N: ”* where *N* is the list counter.
- **Links** – Only the anchor text is read; the URL is dropped.
- **Images** – The image URL is dropped; alt text may optionally be read if present (configurable in future phases).
- **Code blocks** – Skipped by default; a configurable marker phrase *“Code block omitted.”* is inserted.
- **Inline code** – Read token literally, with boundary clean‑up.
- **Tables** – Flattened row‑wise with cell separators (e.g., “cell, cell …”).

These rules are designed to maintain narrative flow and avoid unnatural speech artefacts. The chunking engine (see [[concepts/chunking-for-synthesis]]) then segments the normalized text while respecting sentence and paragraph boundaries, enabling smooth [[concepts/long-form-speech]] synthesis.

### Configurable Behavior
Several aspects are intended to be controllable via CLI flags or future configuration:
- Code‑block placeholder text.
- Whether to read image alt text.
- Silence duration between headings and paragraphs (via `--pause-ms`).

### Relationship to the Pipeline
1. **Markdown parsing** extracts the document structure.
2. **Narration rules** convert it to a single, linear plain‑text string.
3. **Chunking** splits that string into manageable segments for synthesis.

This separation ensures that the TTS backend never sees raw Markdown, and the narration logic remains independent of the underlying model family.