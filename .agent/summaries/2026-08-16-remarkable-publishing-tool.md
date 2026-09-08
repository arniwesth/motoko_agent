# 2026-08-16 Publishing Markdown notes to a reMarkable 2 from the dev container

## Context

Branch: `arniwesth/mot-96-project-and-research-ideas-140826`. Session ran 2026-08-15 evening into
2026-08-16 morning. Entry point was a capability question — *"I would like to be able to send md
(possible converted to pdf) files to my remarkable 2 from this dev container. How could this be
automized?"* — with no constraint on transport, format, or where the code should live.

Delivered as a tool, after one restructure the operator asked for mid-session ("instead of having
the functionality living as scripts, it would be better to make it into an actual tool in
`tools/`. Use typescript instead of a script"):

```text
tools/rmsend/rmsend.ts               607   bun shebang, no runtime deps
tools/rmsend/strip-dead-anchors.lua   41   bundled pandoc filter
tools/rmsend/README.md               117
tools/rmsend/package.json              8   bin: rmsend
```

```text
tools/md2pdf/md2pdf.ts                +21 -2   --paper flag
Makefile                              +46      5 remarkable_* targets
.gitignore                            +8 -1    .remarkable/
.devcontainer/default/devcontainer.json +6 -2  postCreateCommand installs the toolchain
```

An intermediate shell implementation (`scripts/rm-send.sh`, `scripts/install-remarkable.sh`,
`scripts/rm-strip-dead-anchors.lua`) existed for most of the session and was deleted on the
restructure. It was never committed; no references to it survive anywhere in the tree.

Three documents were really uploaded and confirmed present via `rmapi ls /Motoko`.

## Transport decision: cloud, not USB or SSH

A reMarkable 2 is reachable three ways: the USB web interface at `10.11.99.1`, SSH to the device
over the LAN, or the reMarkable Cloud sync API. **Only the third works from a dev container
unconditionally** — the first needs a cable bound to the host, and the second needs a route to a
tablet that may be on a different network than the container. Cloud sync is on reMarkable's free
tier; only file history is paid.

`rmapi` (`ddvk/rmapi` — `juruen/rmapi` is archived) v0.0.34 ships a linux-arm64 static binary and
honours `RMAPI_CONFIG`, which is what makes the setup rebuild-proof: the device token lives at
`<repo>/.remarkable/rmapi.conf`, inside the bind-mounted workspace and gitignored, so
`devcontainer rebuild` does not force a re-pair. Pairing is one interactive step against
`https://my.remarkable.com/device/browser/connect` (8-character code).

**`-ni` on every non-interactive rmapi call is load-bearing.** Without a token and without `-ni`,
rmapi does not fail — it loops forever prompting for a pairing code against a closed stdin. Every
call in the tool passes it except `login`, which is the one that must be allowed to prompt.

## Toolchain: typst, not TeX

`pandoc --pdf-engine=typst` renders Markdown to PDF with no LaTeX anywhere: pandoc 3.10.2 and typst
0.15.1 are ~30MB static binaries each, against ~1GB for `texlive-xetex`. All three tools install
into `~/.local/bin` (already on `PATH` in the image) from pinned GitHub releases.

The repo already had `tools/md2pdf` — pandoc + XeLaTeX with mermaid rendering, `[cite: N]` links,
and landscape rotation for wide tables. That is a better renderer for documents that use those
features and a much heavier one for documents that do not, so `rmsend` delegates to it under
`--converter md2pdf` rather than duplicating it.

`--converter auto` resolves to **typst, unconditionally**. It briefly auto-detected xelatex and
preferred md2pdf when present — which silently changed the default path's output the moment
texlive got installed for an unrelated test. Detection that reroutes the default based on ambient
machine state is worse than a fixed default.

## Page geometry

The rM2 screen is 157.2 x 209.6mm. Output is A5 (148 x 210mm) at 11pt: it fills the page with no
pinch-zooming and leaves a thin side margin. Exact-fit custom dimensions would need a patched
pandoc typst template — a maintenance liability for ~6% of page width.

`md2pdf` produced **US Letter** (612 x 792pt), which the tablet then shrinks to ~72%. Cause:
`buildPandocFlags` set `geometry:margin` and `fontsize` but never a paper size, so LaTeX's default
won. Fixed by adding `--paper <name>` (allowlist: letter, legal, executive, a4, a5, a6, b5) to
md2pdf; **the default is `letter`, so existing md2pdf output is unchanged** — verified by
diffing a no-flag run's page size before and after.

## Four conversion bugs, all found against the repo's real corpus

Testing on `.agent/research` and `.agent/projects` rather than a synthetic file is what surfaced
these. Each one aborted a whole document.

1. **A bare `@handle` is a pandoc citation.** `phoenix-architecture.md` contains `@chadfowler`;
   pandoc emits a typst `#cite`, and typst then aborts with *"the document does not contain a
   bibliography."* Fixed with `--from=markdown-citations`.

2. **A stale `](#anchor)` kills the document.** A link to a renamed heading is a dead link in a
   browser and in LaTeX; typst refuses to compile at all — *"label does not exist."* Notes
   accumulate these as headings get renamed. `strip-dead-anchors.lua` collects every id in a first
   pass, then demotes links whose target is absent to plain spans, keeping the text.

3. **`margin` cannot be passed with `-V`.** Pandoc's typst template iterates `margin/pairs`, so a
   string variable expands to the syntax error `margin: (: ,)`. It has to arrive as a YAML map via
   `--metadata-file`.

4. **The title rendered twice** — once from pandoc's title block, once from the document's own
   `# H1` that the title was extracted from. Present in every send this session before it was
   caught on the last one. `stripTitleHeading` drops the leading heading when it matches the
   title, walking past YAML front matter and stopping at the first real content so it cannot eat a
   mid-document heading.

## Guards against irreversible-ish actions

- **`--replace` is off by default.** rmapi has no in-place update, so replacing is a delete plus a
  fresh upload — it discards annotations made on the tablet. The default failure mode is a
  duplicate document, which is recoverable; the other is not.
- **`branch` refuses past `--max 20`.** This branch is **405 markdown files** ahead of `main`, so
  the obvious "send everything this branch changed" command would have dumped 405 PDFs onto a
  tablet from which pruning is manual.

## Interface

```sh
make remarkable_install                      # rmapi + pandoc + typst (+ --with-latex for md2pdf)
make remarkable_login                        # one time, 8-char code
make remarkable FILE=notes.md                # DIR=, FORMAT=, RM_FLAGS= forward to the tool
bun tools/rmsend/rmsend.ts .agent/research --dir /Motoko/Research --toc
bun tools/rmsend/rmsend.ts branch --dry-run
```

Subcommands: `send` (default, may be omitted), `branch`, `install`, `login`, `ls`. Directory
arguments expand to every `.md` beneath them. Document names come from front matter `title:`, else
the first H1, else the filename.

## Verified

- Strict `tsc --noEmit` clean for both `rmsend.ts` and the edited `md2pdf.ts`, run out-of-tree —
  the repo has no root `tsconfig.json` and `tools/md2pdf` has none either, so there is no
  in-repo typecheck step to hook into.
- 35 files across `.agent/research` and `.agent/projects/015_idea_factory` convert with zero
  failures, exit 0. That corpus is the regression suite; all four bugs above came out of it.
- Real uploads through both converters, both confirmed by `rmapi ls`, with `--replace` verified to
  leave one copy rather than two.
- Exit codes 1 on the guard, missing-file, and bad-flag paths.
- Rendering checked visually page by page, not just by exit status: TOC, tables, inline code, and
  `Φ_RM` / `∘` / `≅` from typst's embedded fonts.

## Open

- **`md2pdf` overflows the right margin on long unbreakable inline code** — repo paths like
  `.agent/projects/014_comparative_self_evolution/RESEARCH-...` run off the page because LaTeX will
  not break `\texttt` at `/`. A5's narrower measure makes it worse than it was on Letter. It
  affects any md2pdf document citing repo paths, independent of reMarkable. Proposed fix, matching
  that tool's existing design: a fourth bundled Lua filter inserting zero-width breaks after `/`,
  `_`, `-` and `.` inside `Code` inlines. **Typst does not have this problem** — visible in the
  page-1 renders, where the same paths wrap cleanly — so the default path is unaffected.
- **texlive is not in the image.** It was installed by hand this session for the md2pdf test;
  `rmsend install --with-latex` reinstalls it after a rebuild. Deliberately out of
  `postCreateCommand`: ~1GB for a path most sends do not take.
- **Nothing is scheduled.** Sending is still an explicit command. A post-commit hook scoped to a
  docs path, or a cron routine for the week's changed research notes, was offered and not taken up.
