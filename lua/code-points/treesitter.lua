local M = {}

--- Registry of language modules, keyed by filetype.
--- @type table<string, CodePointsLang>
local lang_registry = {}

--- Filetype aliases for auto-loading (e.g., typescriptreact → typescript module).
local FT_ALIASES = {
  typescriptreact = "typescript",
  javascriptreact = "javascript",
}

--- Register a language module for all its filetypes.
--- @param lang_module CodePointsLang
function M.register(lang_module)
  for _, ft in ipairs(lang_module.filetypes) do
    lang_registry[ft] = lang_module
  end
end

--- Get the language module for a filetype, with lazy auto-loading.
--- @param ft string Neovim filetype
--- @return CodePointsLang|nil
function M.get_lang(ft)
  -- Return from registry if already loaded
  if lang_registry[ft] then
    return lang_registry[ft]
  end

  -- Try to auto-load by filetype name, then by alias
  local names_to_try = { ft }
  if FT_ALIASES[ft] then
    table.insert(names_to_try, FT_ALIASES[ft])
  end

  for _, name in ipairs(names_to_try) do
    local ok, lang = pcall(require, "code-points.langs." .. name)
    if ok and lang and lang.filetypes then
      M.register(lang)
      if lang_registry[ft] then
        return lang_registry[ft]
      end
    end
  end

  return nil
end

--- Adjust end_row for nodes whose range includes a trailing newline.
--- If end_col is 0 and end_row > start_row, the node ends at the start of
--- end_row (just the trailing newline from the previous line).
--- @param sr number start_row (0-indexed)
--- @param er number end_row (0-indexed)
--- @param ec number end_col
--- @return number adjusted end_row
local function adjust_end_row(sr, er, ec)
  if ec == 0 and er > sr then
    return er - 1
  end
  return er
end

--- Build a single entry from a treesitter node.
--- @param node any treesitter node
--- @param lang CodePointsLang language module
--- @param bufnr number buffer handle
--- @return table entry
local function build_entry(node, lang, bufnr)
  local sr, _, er, ec = node:range()
  er = adjust_end_row(sr, er, ec)

  local name = lang.get_name(node, bufnr)
  if not name or name == "[unknown]" then
    name = "<L" .. (sr + 1) .. ">"
  end

  return {
    name = name,
    display_type = lang.get_display_type(node, bufnr),
    arity = lang.get_arity(node, bufnr),
    start_row = sr,
    end_row = er,
    lines = vim.api.nvim_buf_get_lines(bufnr, sr, er + 1, false),
    children = nil,
  }
end

--- Extract all top-level code points from a buffer using the appropriate language module.
--- @param bufnr number buffer handle
--- @return table[] entries list of entries (with optional children)
--- @return CodePointsLang|nil lang the language module used
function M.get_code_points(bufnr)
  local ft = vim.bo[bufnr].filetype
  local lang = M.get_lang(ft)
  if not lang then
    vim.notify("CodePoints: unsupported filetype: " .. ft, vim.log.levels.WARN)
    return {}, nil
  end

  -- Resolve the treesitter parser name
  local parser_name = lang.parsers and lang.parsers[ft] or ft

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, parser_name)
  if not ok or not parser then
    vim.notify("CodePoints: failed to get treesitter parser for " .. parser_name, vim.log.levels.ERROR)
    return {}, lang
  end

  local tree = parser:parse()[1]
  if not tree then
    vim.notify("CodePoints: failed to parse buffer", vim.log.levels.ERROR)
    return {}, lang
  end

  local root = tree:root()
  local entries = {}

  for child in root:iter_children() do
    if lang.is_declaration(child) then
      local entry = build_entry(child, lang, bufnr)

      -- Check if this node has nestable children (e.g., methods in a class/impl)
      if lang.is_nestable and lang.get_body_node and lang.is_child_declaration then
        if lang.is_nestable(child) then
          local body = lang.get_body_node(child)
          if body then
            entry.children = {}
            for grandchild in body:iter_children() do
              if lang.is_child_declaration(grandchild) then
                local child_entry = build_entry(grandchild, lang, bufnr)
                table.insert(entry.children, child_entry)
              end
            end
            -- If no children found, set to nil
            if #entry.children == 0 then
              entry.children = nil
            end
          end
        end
      end

      table.insert(entries, entry)
    end
  end

  return entries, lang
end

return M
