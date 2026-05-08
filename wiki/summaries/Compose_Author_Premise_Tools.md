---
doc_type: short
full_text: sources/Compose_Author_Premise_Tools.md
---

# Compose Author Premise Tools

**Date:** 2026-04-13 | **Status:** Draft (depends on [[Compose_As_Extension]])

## Goal
Enhance the Compose author pass with **read-only tool access** (`read_file`, `grep`, `list_dir`, `file_exists`, `stat`) running inside the extension host. Every tool result is recorded in a **premise ledger**, which the certificate validator (SF3) uses to verify that each `PREMISES` line in the final snippet is backed by a witnessed file read (ledger-bound) or a snippet-declared effect (snippet-bound).

## Motivation
- **Reduce hallucination:** Premises become citations to actual tool-observed data instead of LLM fabrications.
- **Stronger evidence:** SF3 can concretely check that a quoted excerpt actually appeared in a file.
- **Simplified snippets:** Reads done at author time eliminate the need to declare `FS` effects in the snippet for those same files.
- **Sharper SF5 comparator:** The ledger provides a baseline for premise fidelity checks.

## Key Design

### Protocol
The author LLM emits a `tool_call` fence (JSON inside a Markdown code block) to request a tool action. The extension parses it, executes the tool, appends a ledger entry, and injects the result back as an observation. The loop continues until the author emits an `ailang` fence (final snippet) or hits the budget limit.

- **Provider-neutral** (no native tool-calling API dependency).
- **One action per turn** to keep MVP simple.
- **Sandboxed & denylisted** to prevent path escapes and secret exposure.

### Premise Ledger ([[concepts/Premise Ledger]])
A structured record of all tool calls, results, excerpts, and metadata. Persisted per invocation. Provides query methods for binding checks and telemetry.

### PREMISES Grammar ([[concepts/Tool Witnessed Premises]])
PREMISES lines now use a three-field pipe-delimited format:  
`<path> | "<verbatim_quote>" | <paraphrase>`  
The validator enforces that the quote is a whitespace-normalized substring of a ledger entry for that path (ledger-bound) or that the snippet itself declares an effect to read the file (snippet-bound). This turns premises into verifiable assertions.

### Validation Changes ([[concepts/SF3 Certificate Validation]])
- SF3 extends to parse and classify each premise as **ledger-bound**, **snippet-bound**, **unbound**, or **malformed**.
- Unbound premises cause high-confidence validation failure with retry hints.
- SF2 recalibrates to accept effectless snippets if they contain at least one ledger-bound premise, reducing effect declaration burden for analyze/summarize intents.

### Author Loop ([[concepts/Compose Author Loop]])
A multi-turn state machine implemented in `author_loop.ail` that manages turn-by-turn generation, tool dispatch, ledger accumulation, and budget enforcement. Integrates with the Compose extension behind a feature flag (`AILANG_COMPOSE_AUTHOR_TOOLS`).

## Implementation Plan
Phased over five phases:
1. **Phase 1** — Tool infrastructure: dispatcher, sandbox, denylist, budget, truncation.
2. **Phase 2** — Author loop integration into `compose.ail`, UI rendering.
3. **Phase 3** — Premise-ledger binding in SF3 validator.
4. **Phase 4** — Adjust SF2 and SF5 to consume the ledger.
5. **Phase 5** — Default enablement and documentation.

The feature is fully gated and revertible until the default flip.

## Risks & Mitigations
- **Prompt injection from file contents:** Treated as untrusted data, wrapped in observation envelope.
- **Premise forgery:** Binding check requires exact substring match against the ledger excerpt; truncated files prevent citing unwitnessed content.
- **Token cost:** Budget and byte caps limit worst-case; telemetry tracks actual spend.
- **Secret exposure:** Default path denylist blocks common sensitive files; configurable but auditable.

## Related Concepts
- [[concepts/Evidence Guards]] — the broader SF1–SF5 system this plan extends.
- [[concepts/Compose Extension Architecture]] — required prerequisite for running author tools in the extension host.
- [[concepts/Snippet Validation]] — how SF2, SF3, and SF5 interact to maintain evidence integrity.