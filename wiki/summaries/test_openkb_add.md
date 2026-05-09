---
doc_type: short
full_text: sources/test_openkb_add.md
---

# OpenKB Extension Smoke Test

This document records the smoke test of the OpenKB extension performed on 2026-05-08, with 166 indexed documents.

## Key Findings
- [[concepts/openkbstats]] `OpenKbStatus` correctly reports 166 indexed documents.
- [[concepts/openkblist]] `OpenKbList` lists all documents as expected.
- `OpenKbLint` times out after ~272s, a known issue with large knowledge bases (see [[concepts/openkb-lint-timeout]]).
- `OpenKbQuery` for substantive queries times out after ~58s, likely due to model routing (see [[concepts/openkb-query-timeout]]).
- `OpenKbAdd` returns "Path does not exist" for missing files, confirming proper error handling.

These results highlight performance bottlenecks with large KBs and the need for addressing timeouts in linting and queries.

## Related Concepts
- [[concepts/large-knowledge-base-performance]]
- [[concepts/knowledge-base-extension-validation]]
- [[concepts/structured-agent-memory]]
