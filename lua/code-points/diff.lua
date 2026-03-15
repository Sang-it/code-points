local M = {}

--- Detect the line ending used in a buffer.
--- @param bufnr number buffer handle
--- @return string line_ending "\n" or "\r\n"
local function buf_line_ending(bufnr)
  if vim.bo[bufnr].fileformat == "dos" then
    return "\r\n"
  end
  return "\n"
end

--- Find the length of the common prefix between two strings.
--- @param a string
--- @param b string
--- @return number
local function common_prefix_len(a, b)
  local len = math.min(#a, #b)
  for i = 1, len do
    if a:byte(i) ~= b:byte(i) then
      return i - 1
    end
  end
  return len
end

--- Find the length of the common suffix between two strings.
--- @param a string
--- @param b string
--- @return number
local function common_suffix_len(a, b)
  local a_len = #a
  local b_len = #b
  local len = math.min(a_len, b_len)
  for i = 0, len - 1 do
    if a:byte(a_len - i) ~= b:byte(b_len - i) then
      return i
    end
  end
  return len
end

--- Apply new content to a buffer using minimal diffs.
--- Uses vim.diff to compute change hunks, converts them to LSP TextEdit
--- objects, and applies via vim.lsp.util.apply_text_edits. This avoids
--- whole-buffer replacement which causes syntax highlighting flicker.
--- @param bufnr number buffer handle
--- @param new_lines string[] the new buffer content as a list of lines
function M.apply_minimal(bufnr, new_lines)
  local original_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local line_ending = buf_line_ending(bufnr)

  local original_text = table.concat(original_lines, line_ending) .. line_ending
  local new_text = table.concat(new_lines, line_ending) .. line_ending

  -- Fast path: no changes
  if original_text == new_text then
    return
  end

  -- Compute minimal diff hunks
  local indices = vim.diff(original_text, new_text, {
    result_type = "indices",
    algorithm = "histogram",
  })

  if not indices or #indices == 0 then
    return
  end

  -- Convert diff hunks to LSP TextEdit objects
  local text_edits = {}

  for _, idx in ipairs(indices) do
    local orig_start, orig_count, new_start, new_count = unpack(idx)

    local is_insert = orig_count == 0
    local is_delete = new_count == 0
    local is_replace = not is_insert and not is_delete

    -- Build the replacement text from the new lines
    local replacement = {}
    if not is_delete then
      for i = new_start, new_start + new_count - 1 do
        table.insert(replacement, new_lines[i])
      end
    end

    local new_text_str = table.concat(replacement, line_ending)

    -- Compute the range in the original buffer
    local start_line, start_char, end_line, end_char

    if is_insert then
      -- Insert after orig_start (which is the line before the insertion point)
      -- In LSP terms, insert at the beginning of the next line
      start_line = orig_start
      start_char = 0
      end_line = orig_start
      end_char = 0
      new_text_str = new_text_str .. line_ending
    elseif is_delete then
      start_line = orig_start - 1 -- convert to 0-indexed
      start_char = 0
      end_line = orig_start + orig_count - 1 -- 0-indexed, exclusive end line
      end_char = 0
      new_text_str = ""
    else
      -- Replace
      local orig_line_start = orig_start -- 1-indexed
      local orig_line_end = orig_start + orig_count - 1 -- 1-indexed

      start_line = orig_line_start - 1 -- 0-indexed
      start_char = 0
      end_line = orig_line_end - 1 -- 0-indexed
      end_char = #original_lines[orig_line_end]

      -- Try to narrow the edit with common prefix/suffix on the boundary lines
      if is_replace and #replacement > 0 then
        local prefix = common_prefix_len(original_lines[orig_line_start] or "", replacement[1])
        if prefix > 0 then
          start_char = prefix
          replacement[1] = replacement[1]:sub(prefix + 1)
        end

        local suffix = common_suffix_len(original_lines[orig_line_end] or "", replacement[#replacement])
        if orig_line_end == orig_line_start then
          suffix = math.min(suffix, #(original_lines[orig_line_end] or "") - prefix)
        end
        if suffix > 0 then
          end_char = #(original_lines[orig_line_end] or "") - suffix
          replacement[#replacement] = replacement[#replacement]:sub(1, #replacement[#replacement] - suffix)
        end

        new_text_str = table.concat(replacement, line_ending)
      end
    end

    table.insert(text_edits, {
      range = {
        start = { line = start_line, character = start_char },
        ["end"] = { line = end_line, character = end_char },
      },
      newText = new_text_str,
    })
  end

  -- Apply the minimal edits
  vim.lsp.util.apply_text_edits(text_edits, bufnr, "utf-8")
end

return M
