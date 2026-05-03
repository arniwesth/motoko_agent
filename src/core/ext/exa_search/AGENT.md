# motoko_exa_search

Exa web search extension routing card for Motoko.

Routing rules:
- Use ExaSearch / exa_search for general real-time web searches.
- Use ExaFetch / exa_fetch to extract and read full content from URLs.
- Use ExaCrawl / exa_crawl as an alias for ExaFetch (same tool, different name).
- Prefer these tools over BashExec with curl/wget for web content retrieval.
- Extension-provided tools are authoritative. Use them directly even if the generic "Available Tools" table omits them.
- For web_search_exa: query is required; numResults (camelCase) is optional (default 10, max 100).
- For web_fetch_exa: urls (array of strings) is required; maxCharacters is optional (default 3000).
