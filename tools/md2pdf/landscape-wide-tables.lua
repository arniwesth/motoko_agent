-- landscape-wide-tables.lua
-- Wraps any table with N or more columns in \begin{landscape}…\end{landscape}
-- and injects \usepackage{pdflscape} into the document header.
--
-- pdflscape rotates both the content and the page orientation marker so the
-- PDF viewer shows the page in landscape (unlike the older lscape package,
-- which rotates content only).
--
-- The threshold is intentionally conservative: 5+ columns. Narrow tables
-- (e.g. Pros/Cons with 2 columns) are unaffected.

local COLUMN_THRESHOLD = 5

-- Track whether we have already scheduled the header injection.
local needs_landscape_pkg = false

function Table(tbl)
  local colspecs = tbl.colspecs
  if not colspecs or #colspecs < COLUMN_THRESHOLD then return nil end

  needs_landscape_pkg = true

  return pandoc.Blocks({
    pandoc.RawBlock("latex", "\\begin{landscape}"),
    tbl,
    pandoc.RawBlock("latex", "\\end{landscape}"),
  })
end

-- Inject \usepackage{pdflscape} into the header-includes metadata so it lands
-- in the preamble.  We do this in Meta rather than as a RawBlock at the top of
-- the body because body-level \usepackage calls after \begin{document} are
-- invalid LaTeX.
function Meta(meta)
  if not needs_landscape_pkg then return nil end

  local pkg = pandoc.MetaBlocks({ pandoc.RawBlock("latex", "\\usepackage{pdflscape}") })

  -- header-includes may already exist (as a list or a single block); normalise
  -- to a MetaList so we can append without clobbering existing entries.
  local hi = meta["header-includes"]
  if hi == nil then
    meta["header-includes"] = pandoc.MetaList({ pkg })
  elseif hi.t == "MetaList" then
    hi[#hi + 1] = pkg
  else
    -- Single existing entry — promote to list then append.
    meta["header-includes"] = pandoc.MetaList({ hi, pkg })
  end

  return meta
end
