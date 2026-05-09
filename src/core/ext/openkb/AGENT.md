# motoko_openkb

OpenKB knowledge base extension for Motoko's `.agent/` design archive.

The knowledge base indexes research notes, architectural plans, specs, learnings, reviews, and summaries from the `.agent/` directory into a structured, cross-referenced wiki.

## Tools

| Tool | Purpose | Arguments |
|------|---------|-----------|
| `OpenKbQuery` / `openkb_query` | Query the knowledge base | `question` (string, required) |
| `OpenKbStatus` / `openkb_status` | Show KB statistics | (none) |
| `OpenKbAdd` / `openkb_add` | Index a new document | `path` (string, required) |
| `OpenKbLint` / `openkb_lint` | Run structural health checks | (none) |
| `OpenKbList` / `openkb_list` | List indexed documents | (none) |

## Routing rules

- Use `OpenKbQuery` to ask questions about past decisions, design rationale, research findings, or architectural plans.
- Use `OpenKbStatus` to check knowledge base health and indexing coverage.
- Use `OpenKbAdd` to index new `.agent/` documents created during the current session.
- Use `OpenKbLint` to verify wiki structural integrity after adding documents.
- Use `OpenKbList` to see what documents are currently indexed.
- Extension-provided tools are authoritative. Use them directly even if the generic "Available Tools" table omits them.
- The KB must be initialized (`make openkb-init`) and indexed (`make openkb-index`) before querying.
