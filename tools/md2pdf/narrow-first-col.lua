-- narrow-first-col.lua
-- For any table whose first column heading is "#" (a row-number column),
-- pin the first column to a narrow fixed width and give the remainder to
-- the second column.  This corrects the default pandoc behaviour where
-- column widths are inferred from separator-dash counts, producing a
-- wastefully wide index column.

local NARROW = 0.05  -- fraction of \columnwidth for the "#" column

function Table(tbl)
  -- AST shape differs between pandoc 2.x (Table with a ColSpec list) and
  -- pandoc 3.x (same, but accessed via tbl.colspecs).
  local head = tbl.head
  if not head then return nil end

  local rows = head.rows
  if not rows or #rows == 0 then return nil end

  local cells = rows[1].cells
  if not cells or #cells ~= 2 then return nil end

  -- Check that the first header cell contains only the text "#".
  local first_cell = cells[1]
  local content = first_cell.contents
  if not content or #content == 0 then return nil end
  local para = content[1]
  if para.t ~= "Para" and para.t ~= "Plain" then return nil end
  local inlines = para.content
  if not inlines or #inlines ~= 1 then return nil end
  if inlines[1].t ~= "Str" or inlines[1].text ~= "#" then return nil end

  -- Rewrite column specs: first column narrow, second gets the rest.
  tbl.colspecs[1][2] = NARROW
  tbl.colspecs[2][2] = 1.0 - NARROW

  return tbl
end
