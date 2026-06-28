# Research: Project Memory Index for `.agent`, Git History, and Source Graphs

Date: 2026-06-28
Status: Research note
Context: Follow-on idea from ADR-002 `ailang-graph` and ADR-003 SQL source index

## Summary

The code graph and source index are beginning to form a broader project-memory
system. Today:

- `ailang-graph` answers structural and effect questions about current AILANG code.
- The SQL source index answers profile-aware, stale-aware source search questions.

A natural next layer is a **project memory index** that loads `.agent` research,
ADRs, implementation plans, handoffs, summaries, and git history into the same
ClickHouse/chDB query surface. This would let agents ask not only "where is this code?"
or "what effects can this function reach?", but also:

- Which plan or ADR likely led to a code change?
- Which research notes, ADRs, and plans overlap on the same paths, symbols, or ideas?
- Which plans became stale because referenced files changed?
- Which commits implemented or modified files mentioned by a specific ADR?
- Which previous decisions explain why a module or function is shaped this way?

The first version should stay SQL-first and evidence-oriented. It should not claim
proven causality where it only has overlap signals.

## Simple ClickHouse-Backed Shape

"Simple and ClickHouse-backed" means using the same design discipline as the source
index:

- Extract files into generated CSV tables under `tools/code-graph/.out/`.
- Query those CSVs through chDB `file(..., 'CSVWithNames')`.
- Use ordinary SQL string functions, regexes, joins, grouping, and metadata.
- Avoid persistent services, graph databases, embeddings, vector search, or LLM-only
  inference in v1.

Likely v1 tables:

```text
agent_docs
- path
- kind              -- ADR, plan, handoff, summary, research, prompt, other
- title
- status
- created_at
- updated_at
- bytes
- sha256

agent_doc_sections
- path
- section_slug
- heading
- level
- start_line
- end_line
- text

agent_doc_refs
- from_path
- to_path
- ref_kind          -- mentions, supersedes, implements, reviews, blocks

git_commits
- commit
- author_name
- author_time
- subject
- body

git_changed_files
- commit
- path
- additions
- deletions
- status

git_hunks
- commit
- path
- old_start
- old_lines
- new_start
- new_lines
- hunk_text
```

The design principle is:

> ClickHouse stores inspectable evidence, not final conclusions.

For example, a derived table can record plan-to-code evidence without pretending that
causality is certain:

```text
plan_code_evidence
- plan_path
- plan_section
- commit
- changed_path
- evidence_kind      -- mentioned_path, mentioned_symbol, temporal_window, commit_msg_ref
- score
- evidence_text
```

## Example Questions

Find commits touching files mentioned by ADR-003:

```sql
SELECT c.commit, c.author_time, c.subject, f.path
FROM agent_doc_sections s
JOIN git_changed_files f
  ON positionCaseInsensitive(s.text, f.path) > 0
JOIN git_commits c
  ON c.commit = f.commit
WHERE s.path LIKE '%.agent/%ADR-003%'
ORDER BY c.author_time;
```

Find planning docs that mention source-index join keys:

```sql
SELECT path, heading, start_line
FROM agent_doc_sections
WHERE positionCaseInsensitive(text, 'source_chunks') > 0
   OR positionCaseInsensitive(text, 'func_slug') > 0
ORDER BY path, start_line;
```

Find research or plan overlap by shared source paths:

```sql
SELECT a.path AS left_doc, b.path AS right_doc, sf.path AS mentioned_source
FROM source_files sf
JOIN agent_doc_sections a ON positionCaseInsensitive(a.text, sf.path) > 0
JOIN agent_doc_sections b ON positionCaseInsensitive(b.text, sf.path) > 0
WHERE a.path < b.path
ORDER BY mentioned_source, left_doc, right_doc;
```

Join design notes to function-level code/effects through existing source chunks:

```sql
SELECT s.path AS doc, s.heading, c.func_slug, e.effect, c.path AS source_path
FROM agent_doc_sections s
JOIN source_chunks c
  ON positionCaseInsensitive(s.text, c.name) > 0
JOIN effect_edges e
  ON e.func_slug = c.func_slug
WHERE e.effect = 'Net'
ORDER BY doc, c.path, c.start_line;
```

## Evidence Signals

Useful v1 evidence signals:

- A plan or ADR explicitly mentions a source path that a commit later changes.
- A plan or ADR mentions a function, module, table, or slug found in source chunks.
- A commit message mentions an ADR ID, plan filename, task number, or phrase.
- A changed hunk contains text, symbols, or table names from a plan.
- A handoff summary names completed files that appear in a commit.
- A plan timestamp precedes a relevant commit within a bounded time window.

Each signal should be recorded with `evidence_kind`, `score`, and enough context to
audit the row. The system should phrase answers as "evidence suggests" unless a
strong explicit reference exists, such as a commit message naming an ADR.

## When CSV-Backed chDB Is Enough

CSV-backed chDB is likely enough while:

- `.agent` document volume is small.
- Full regeneration is cheap.
- Git history scans are acceptable.
- Queries are mostly exact text, regex, path, symbol, timestamp, and join questions.
- Agents need transparent evidence more than fuzzy semantic recall.

This stage can answer many valuable questions without extra infrastructure.

## When To Materialize ClickHouse Tables

Move beyond CSV-backed chDB, but still stay ClickHouse-backed, when:

- Query startup time or CSV scan time becomes annoying.
- Git hunks become large enough to make repeated scans slow.
- Incremental updates are needed instead of full regeneration.
- Native ClickHouse text indexes become useful.
- Derived evidence views become expensive to recompute on every query.
- Multiple tools need to query the same indexed state consistently.

A later command could look like:

```bash
tools/code-graph/index.sh --materialize
```

That would create local persistent tables and materialized views while preserving the
same logical schemas.

## When To Move Beyond ClickHouse

Move beyond ClickHouse as the whole system when the dominant questions become
semantic, fuzzy, or graph-inference heavy:

- Find conceptually similar plans that share few exact terms.
- Detect duplicate research ideas across paraphrases.
- Resolve entities across docs, commits, summaries, and code despite name drift.
- Infer likely causality beyond path/symbol/time overlap.
- Explore many-hop relationships interactively with graph algorithms.
- Rank related research by semantic similarity rather than SQL predicates.
- Synthesize long explanations from many project-memory records.

At that point, ClickHouse should remain the evidence warehouse, but additional layers
may be justified:

```text
ClickHouse:
  exact facts, sections, source lines, chunks, hunks, commits, graph edges, timestamps

Graph layer:
  explicit relationships: implements, supersedes, references, changes, validates

Vector index:
  semantic recall over doc sections, source chunks, commit messages, and summaries

LLM/reranker:
  synthesis, clustering, explanation, and causality hypotheses
```

The critical requirement is auditability: if a semantic layer claims "ADR-003 led to
this code," the ClickHouse evidence tables should show the ADR section, mentioned
paths or symbols, relevant commit, and changed hunk.

## EmbeddingGemma as a Semantic Recall Layer

EmbeddingGemma is a plausible candidate for v3, the hybrid semantic layer. It should
not replace ClickHouse. It should sit beside it as a recall layer for fuzzy similarity
and candidate generation.

Recommended shape:

```text
ClickHouse/chDB:
  exact evidence tables
  agent_doc_sections
  source_chunks
  git_hunks
  git_commits
  graph/effect tables

EmbeddingGemma:
  vector for each agent document section
  vector for each AILANG source chunk
  vector for each commit message or hunk summary

Query flow:
  1. Use embeddings to retrieve semantically related candidate records.
  2. Join those candidates back to ClickHouse by stable ids.
  3. Use ClickHouse metadata to show paths, lines, hashes, commits, graph joins,
     source staleness, and effect coverage.
```

This fits questions such as:

- Find plans conceptually related to ADR-003 even if they share few exact terms.
- Find older research notes that overlap with a new implementation plan.
- Find code chunks semantically related to a handoff summary.
- Cluster `.agent` notes into themes.
- Detect possible duplicate or overlapping plans written with different wording.

For a first implementation, store vectors in a small local sidecar rather than forcing
them into ClickHouse:

```text
agent_embeddings
- item_id
- item_kind       -- agent_section, source_chunk, git_hunk, commit
- path
- section_slug
- func_slug
- commit
- sha256
- model
- embedding
```

Chunking matters. `.agent` documents should be embedded at section granularity, not as
whole files. Source code should use `source_chunks` for AILANG functions. Git history
should use commit messages, hunk-level text, or short generated hunk summaries rather
than entire large diffs.

The retrieval contract should remain evidence-first: EmbeddingGemma can propose that
items are related, but ClickHouse should provide the inspectable evidence rows. Any
answer that implies causality should still point to explicit paths, sections, changed
files, commits, and hunks.

## Local DeepSeek V4 Flash vs EmbeddingGemma

If a local DeepSeek V4 Flash model is available and practically free to use, it should
probably complement EmbeddingGemma rather than replace it.

Expected split:

```text
EmbeddingGemma:
  primary embedding model
  cheap vector generation
  semantic similarity
  clustering
  duplicate-plan detection
  nearest-neighbor candidate retrieval

ClickHouse:
  exact evidence store
  source paths, doc sections, hashes, commits, hunks, graph joins, freshness metadata

DeepSeek V4 Flash:
  query rewriting and expansion
  hunk and section summarization
  entity extraction
  doc kind/status classification
  reranking top semantic candidates
  explaining overlap
  judging whether evidence looks implemented, partial, or unrelated
```

DeepSeek V4 Flash is likely better for reasoning-heavy and synthesis-heavy tasks:

- Turn a vague request into several exact source/doc/git search queries.
- Extract mentioned files, symbols, ADR ids, plan ids, effects, and decision status
  from `.agent` sections.
- Summarize large git hunks before embedding them.
- Generate short labels for clusters of related plans or research notes.
- Rerank the top N EmbeddingGemma hits by actual relevance.
- Explain why two plans overlap.
- Compare a plan section against a changed hunk and classify the evidence as
  `implemented`, `partial`, `related`, or `unrelated`.

EmbeddingGemma is likely better for the primary vector index because it is
purpose-built for embeddings. A chat/reasoning model should only become the primary
embedding model if the local serving stack exposes a stable embeddings endpoint or a
well-tested pooling strategy. Otherwise, using a chat model's hidden states directly
risks creating a brittle, hard-to-compare vector space.

Recommended combined flow:

```text
Index time:
  .agent section -> DeepSeek summary/entities -> EmbeddingGemma vector
  source chunk   -> EmbeddingGemma vector
  git hunk       -> DeepSeek hunk summary -> EmbeddingGemma vector

Query time:
  user query -> DeepSeek query expansion
             -> EmbeddingGemma nearest-neighbor retrieval
             -> ClickHouse evidence joins
             -> DeepSeek rerank/explanation over top candidates
```

Even with a strong local reasoning model, the audit boundary stays the same:
DeepSeek can propose, summarize, classify, and explain, but durable claims should be
backed by ClickHouse rows containing concrete paths, sections, commits, changed files,
source chunks, and hunks.

## Suggested Progression

1. v1: CSV + chDB
   Index `.agent` docs and git metadata. Add exact/regex/path/symbol overlap queries.

2. v2: Materialized ClickHouse
   Add persistent local tables, materialized overlap views, and possibly native text
   indexes.

3. v3: Hybrid semantic layer
   Add embeddings only for fuzzy related-research and duplicate-plan detection.

4. v4: Project memory graph
   Add typed relationships and confidence-scored provenance across ADRs, plans,
   handoffs, commits, code chunks, and effect graph nodes.

## Open Questions

- Should this live under `tools/code-graph/`, or become a sibling project-memory tool
  that imports code-graph/source-index tables?
- What `.agent` document taxonomy is stable enough for `kind` classification?
- Should git history extraction index all history or only commits after a project
  start date?
- How should scores be calibrated so they are useful without implying certainty?
- Which named queries should be first-class in `cgq.py`, and which should remain raw
  SQL examples?
