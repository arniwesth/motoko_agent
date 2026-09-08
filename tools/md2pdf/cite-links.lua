--- cite-links.lua — Pandoc Lua filter
--- Transforms "[cite: N, M, ...]" text into superscript hyperlinks
--- pointing to anchored source entries in the Sources list.
---
--- The Sources list is identified as the last OrderedList in the document.
--- Only that list gets id="cite-N" anchors.

-- We need a two-pass approach: first collect all ordered lists to find
-- the last one, then apply anchors only to it.

-- Track all OrderedList elements and their positions
local last_ordered_list = nil
local last_ordered_list_id = 0
local list_counter = 0

-- First pass: identify which ordered list is the Sources list (the last one)
function Pandoc(doc)
  -- Count ordered lists to find the last one
  local total_lists = 0
  doc:walk({
    OrderedList = function(_)
      total_lists = total_lists + 1
    end
  })

  -- Now walk again, applying anchors only to the last ordered list
  -- and transforming citations in all inlines
  local current_list = 0
  local new_doc = doc:walk({
    OrderedList = function(ol)
      current_list = current_list + 1
      if current_list == total_lists then
        -- This is the Sources list — add anchors
        local new_items = {}
        for idx, item in ipairs(ol.content) do
          local num = ol.start + idx - 1
          local div = pandoc.Div(item, pandoc.Attr("cite-" .. tostring(num), {}, {}))
          new_items[#new_items + 1] = {div}
        end
        ol.content = new_items
        return ol
      end
      return nil -- leave other lists unchanged
    end
  })

  return new_doc
end

-- Process inline citations: [cite: 1, 2, 3] → superscript linked numbers
function Inlines(inlines)
  -- Quick check: does this inline sequence contain a citation?
  local text = pandoc.utils.stringify(pandoc.Inlines(inlines))
  if not text:find("%[cite:") then
    return nil
  end

  local out = {}
  local i = 1
  local changed = false

  while i <= #inlines do
    local cite_start = nil
    local cite_end = nil
    local cite_text = ""

    if inlines[i].t == "Str" and inlines[i].text:find("%[cite:") then
      cite_start = i
      cite_text = ""
      local j = i
      while j <= #inlines do
        if inlines[j].t == "Str" then
          cite_text = cite_text .. inlines[j].text
        elseif inlines[j].t == "Space" then
          cite_text = cite_text .. " "
        else
          break
        end
        if cite_text:find("%]") then
          cite_end = j
          break
        end
        j = j + 1
      end
    end

    if cite_start and cite_end then
      -- Extract prefix text before [cite:
      local prefix_text = inlines[cite_start].text:match("^(.-)%[cite:")
      if prefix_text and prefix_text ~= "" then
        out[#out + 1] = pandoc.Str(prefix_text)
      end

      -- Parse citation numbers
      local cite_body = cite_text:match("%[cite:%s*(.-)%]")
      if cite_body then
        local nums = {}
        for n in cite_body:gmatch("%d+") do
          nums[#nums + 1] = tonumber(n)
        end

        -- Build superscript linked numbers
        local sup_inlines = {}
        for idx, num in ipairs(nums) do
          if idx > 1 then
            sup_inlines[#sup_inlines + 1] = pandoc.Str(",")
          end
          local link = pandoc.Link(
            pandoc.Str(tostring(num)),
            "#cite-" .. tostring(num),
            "",
            pandoc.Attr("", {}, {})
          )
          sup_inlines[#sup_inlines + 1] = link
        end
        out[#out + 1] = pandoc.Superscript(sup_inlines)
      end

      -- Extract suffix text after ]
      local last_str = ""
      if inlines[cite_end].t == "Str" then
        last_str = inlines[cite_end].text
      end
      local suffix_text = last_str:match("%](.+)$")
      if suffix_text and suffix_text ~= "" then
        out[#out + 1] = pandoc.Str(suffix_text)
      end

      i = cite_end + 1
      changed = true
    else
      out[#out + 1] = inlines[i]
      i = i + 1
    end
  end

  if changed then
    return pandoc.Inlines(out)
  end
  return nil
end
