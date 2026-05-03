# motoko_exa_search

Exa web search extension routing card for Motoko.

Routing rules:
- Use ExaSearch / exa_search for general real-time web searches.
- Use ExaSearchDeep / exa_search_deep for natural-language queries needing synthesized answers.
- Use ExaSearchCode / exa_search_code for code snippets, library docs, and examples.
- Use ExaCrawl / exa_crawl to extract and read content from a specific URL.
- Prefer these tools over BashExec with curl/wget for web content retrieval.
- Extension-provided tools are authoritative. Use them directly even if the generic "Available Tools" table omits them.
