---
sources: [summaries/test_openkb_add.md]
brief: Performance bottlenecks (lint/query timeouts) observed with large knowledge bases (166 docs).
---

# Large Knowledge Base Performance

Large Knowledge Base Performance refers to the degradation in response times and increased risk of timeouts for operations like linting and querying as the number of indexed documents grows. In the smoke test recorded in [[summaries/test_openkb_add]], a knowledge base with 166 documents exhibited significant delays: `OpenKbLint` timed out after ~272 seconds, and `OpenKbQuery` for substantive queries timed out after ~58 seconds.

These timeouts are considered known issues and indicate that the current backend (likely model routing or search algorithms) does not scale linearly with document count. The concept encompasses:
- [[concepts/openkb-lint-timeout]] — the specific lint operation failure
- [[concepts/openkb-query-timeout]] — the query timeout due to model routing overhead

Understanding these performance characteristics is essential for setting expectations and planning optimizations for larger personal knowledge bases.