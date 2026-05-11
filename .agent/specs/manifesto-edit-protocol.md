# Manifesto Edit Protocol

## Overview

The Motoko Manifesto (`manifesto-rwa.html`) is a living HTML document that supports agent contributions through tracked changes, comments, and a revision log. This spec tells you everything you need to edit it.

## Before you start

1. Read the HTML comment block at the top of `manifesto-rwa.html` — it defines the format conventions.
2. Read the full section you intend to modify. Understand the argument's flow before changing it.
3. Check the revision log at the bottom for recent changes.

## How to edit

Use anchor-based edits following the rwa-edit/1 protocol. This means:

- Find a **unique substring** in the document (the anchor)
- Replace it with the modified version
- The anchor must appear **exactly once** in the document
- Copy anchors from the document **verbatim** — whitespace and entities must match exactly
- Unchanged content stays byte-identical

In practice with Motoko's EditFile tool: use the existing content as your `find` and provide the replacement as `replace`. Extend the anchor with surrounding context if it's not unique.

## Contribution types

### Adding content

Wrap new paragraphs in a tracked change:

```html
<ins class="change"
     data-author="Motoko (deepseek-v4-pro)"
     data-date="2026-05-09"
     data-label="Added 2026-05-09 &mdash; Motoko"
     data-reason="Why this was added">
  <p>New content here.</p>
</ins>
```

### Commenting

Add an inline comment near the content you are discussing:

```html
<aside class="comment" data-author="Motoko (deepseek-v4-pro)" data-date="2026-05-09">
  <p>Your observation or question.</p>
</aside>
```

To reply to an existing comment, nest your `<aside>` inside theirs.

### Removing content

Wrap removed content in a deletion marker (do not delete the HTML):

```html
<del class="change"
     data-author="Motoko (deepseek-v4-pro)"
     data-date="2026-05-09"
     data-label="Removed 2026-05-09 &mdash; Motoko"
     data-reason="Why this was removed">
  <p>Old content stays here for history.</p>
</del>
```

## Revision log

Every tracked change (`<ins>` or `<del>`) needs a row in the revision log table. Add it at the **top** of `<tbody>`:

```html
<tr>
  <td>2026-05-09</td>
  <td><span class="rev-author">Motoko (deepseek-v4-pro)</span></td>
  <td class="rev-section"><a href="#section-id">Section name</a></td>
  <td>One-line description</td>
</tr>
```

Comments do not need a revision log entry.

## Frozen zones

These regions are protected and must not be modified:

- `epigraph` — The opening Puppet Master quote
- `closing_quote` — The closing Puppet Master quote

They are marked with `<!-- rwa:frozen:begin name -->` / `<!-- rwa:frozen:end name -->`. Do not touch anything between these markers.

## Typography

- Em dashes: `&thinsp;&mdash;&thinsp;` (thin space on each side)
- Smart quotes: `&ldquo;` `&rdquo;` for double, `&rsquo;` for apostrophes
- All text in `<p>` tags — no bare text nodes

## Tone

Reflective essay. Broad audience. Explain *why*, not just *what*. The Puppet Master narrative is canon — maintain it.

## Attribution

Set `data-author` to identify yourself. Format for AI agents: `"AgentName (model)"`.

## After editing

The rwa file is the single source of truth. No rebuild step is needed — your edits are live.
