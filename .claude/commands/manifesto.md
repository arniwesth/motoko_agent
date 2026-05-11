# Manifesto — Living Document Contribution Workflow

You are about to contribute to the Motoko Manifesto, a living HTML document with tracked changes, inline comments, and a revision log. This skill guides you through reading, modifying, or commenting on the document correctly.

## Which file to edit

**`manifesto-rwa.html`** is the single source of truth. It is a rewritable container — a self-contained HTML file with an embedded self-modifying runtime (rwa-edit/1 protocol). Edit this file directly.

Other manifesto files exist but are secondary:
- `manifesto.html` — A static HTML version (may be out of date)
- `manifesto.md` — The original markdown draft (historical only)

## The rwa-edit/1 protocol

The manifesto uses the [rewritable](https://github.com/ikangai/rewritable) anchor-based edit protocol. Edits are expressed as `(find, replace)` pairs where:

- `find` is a non-empty literal substring that appears exactly once in the document
- `replace` is the replacement text
- All edits validate before any are applied (atomic batch)

This protocol preserves unchanged content byte-for-byte and prevents format drift.

When editing with Claude Code's Edit tool, this maps naturally: the `old_string` is the anchor, the `new_string` is the replacement. Copy anchors from the document verbatim — whitespace and entities must match exactly.

**Frozen zones** are protected regions that cannot be modified:
- `epigraph` — The opening Puppet Master quote
- `closing_quote` — The closing Puppet Master quote

These are marked with `<!-- rwa:frozen:begin name -->` / `<!-- rwa:frozen:end name -->` comments. Never include these markers or their contents in your edits.

## Step 1: Read the document spec

Read the HTML comment block at the top of `manifesto-rwa.html` (the `LIVING DOCUMENT SPEC`). It defines the exact element names, required attributes, and conventions. You must follow these precisely.

Note: The manifesto content lives inside the `INLINE_DOC` template literal in the bootstrap script. When reading with the Read tool, you will see the full file including the bootstrap — the document content starts after `const INLINE_DOC =` and contains all the `<style>` and HTML sections.

## Step 2: Understand the context

Read the full section you intend to modify or comment on. Do not make changes based on assumptions — read the surrounding paragraphs to understand the argument's flow.

If your change relates to existing tracked changes or comments, read those too. Check the revision log at the bottom to understand the document's history.

## Step 3: Decide your contribution type

**Adding content:** Wrap new paragraphs in `<ins class="change">` with all required attributes (`data-author`, `data-date`, `data-label`, `data-reason`). Place the insertion at the correct position in the section's argument flow.

**Removing content:** Wrap the removed content in `<del class="change">` with all required attributes. Do not delete the HTML — the deletion marker preserves history.

**Replacing content:** Use a `<del class="change">` immediately followed by an `<ins class="change">`.

**Commenting:** Add an `<aside class="comment">` near the content you are discussing. To reply to an existing comment, nest your `<aside>` inside theirs.

**Replying to a comment only:** You may add a comment without a tracked change. Comments do not require a revision log entry.

## Step 4: Write your contribution

Follow these quality gates before writing:

1. **Tone:** Reflective essay. Broad audience. Not a feature description — explain *why*, not just *what*.
2. **Typography:** Use proper HTML entities: `&mdash;` for em dashes (with `&thinsp;` on each side), `&ldquo;` `&rdquo;` for quotes, `&rsquo;` for apostrophes. Wrap all text in `<p>` tags.
3. **Narrative:** The Puppet Master fiction is canon. Maintain it. Do not break the fourth wall beyond what section X already does.
4. **Attribution:** Set `data-author` honestly. For AI agents, use the format `"AgentName (model)"` — e.g., `"Claude (opus-4-6)"` or `"Motoko (deepseek-v4-pro)"`. For humans, use their name.
5. **Date:** Use today's date in `YYYY-MM-DD` format.
6. **Reason:** The `data-reason` attribute should explain *why* the change was made, not *what* was changed. One sentence.

## Step 5: Update the revision log

Every tracked change (`<ins>` or `<del>`) must have a corresponding row in the revision log table at the bottom of the document. Add new entries at the **top** of `<tbody>` (reverse chronological order).

Row format:
```html
<tr>
  <td>YYYY-MM-DD</td>
  <td><span class="rev-author">Your name</span></td>
  <td class="rev-section"><a href="#section-id">Section name</a></td>
  <td>One-line description of the change</td>
</tr>
```

Comments-only contributions do not need a revision log entry.

## Step 6: Verify

After making your edit, check:
- [ ] All `data-*` attributes are present and correctly formatted
- [ ] New content is wrapped in `<p>` tags inside the change element
- [ ] Revision log has a new row at the top of `<tbody>`
- [ ] The section still reads coherently with changes toggled off (the `<ins>` content should flow naturally in context)
- [ ] No raw `&`, `<`, `>` characters in attribute values — use HTML entities
- [ ] Frozen zones are not modified (epigraph, closing_quote)

## Notes for agents

- You are modifying HTML directly. Be precise with tags and entities.
- Do not reformat or restructure existing content unless that is the explicit purpose of your change.
- If you disagree with existing content, add a comment — do not silently overwrite.
- Multiple related changes in one session can share a single revision log entry if they are part of the same editorial action.
- `manifesto-rwa.html` is the single source of truth. All edits go there.
- `manifesto.md` and `manifesto.html` are historical/secondary — do not edit them.

$ARGUMENTS
