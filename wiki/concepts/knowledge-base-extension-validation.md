---
sources: [summaries/test_openkb_add.md]
brief: Testing the OpenKB extension to validate indexing, listing, linting, querying, and error handling.
---

# Knowledge Base Extension Validation

The validation of the OpenKB extension ensures that its commands behave correctly under real-world conditions. The smoke test captured in [[summaries/test_openkb_add]] checks five core functionalities after indexing 166 documents.

## Core Validation Areas
- **Status reporting**: `OpenKbStatus` reliably returns the document count (see [[concepts/openkbstats]]).
- **Listing**: `OpenKbList` produces a complete inventory of indexed files (see [[concepts/openkblist]]).
- **Linting**: `OpenKbLint` runs but may time out on large knowledge bases – a known scalability concern (see [[concepts/openkb-lint-timeout]]).
- **Queries**: `OpenKbQuery` returns results for trivial lookups but times out for complex analysis, suggesting model routing issues (see [[concepts/openkb-query-timeout]]).
- **Error handling**: `OpenKbAdd` correctly rejects nonexistent file paths, proving robust input validation.

## Key Insights
The test reveals performance bottlenecks when the knowledge base grows beyond ~150 documents, particularly in linting and query depth. Addressing these timeouts would improve the extension’s reliability and user experience.