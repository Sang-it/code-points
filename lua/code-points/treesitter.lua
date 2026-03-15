local M = {}

-- Node types we consider as reorderable code points
local DECLARATION_TYPES = {
  function_declaration = "function",
  lexical_declaration = "variable",
  variable_declaration = "variable",
  class_declaration = "class",
  interface_declaration = "interface",
  type_alias_declaration = "type",
  enum_declaration = "enum",
  export_statement = "export",
  expression_statement = "expression",
}

-- Node types we skip entirely
local SKIP_TYPES = {
  comment = true,
  import_statement = true,
}

--- Extract the identifier name from a declaration node.
--- @param node any treesitter node
--- @param bufnr number buffer handle
--- @return string name
local function get_declaration_name(node, bufnr)
  local node_type = node:type()

  -- For function, class, interface, enum, type_alias: use the "name" field
  if node_type == "function_declaration"
    or node_type == "class_declaration"
    or node_type == "interface_declaration"
    or node_type == "enum_declaration"
    or node_type == "type_alias_declaration"
  then
    local name_node = node:field("name")[1]
    if name_node then
      return vim.treesitter.get_node_text(name_node, bufnr)
    end
  end

  -- For lexical_declaration / variable_declaration: find the first variable_declarator
  if node_type == "lexical_declaration" or node_type == "variable_declaration" then
    for child in node:iter_children() do
      if child:type() == "variable_declarator" then
        local name_node = child:field("name")[1]
        if name_node then
          return vim.treesitter.get_node_text(name_node, bufnr)
        end
      end
    end
  end

  -- For export_statement: look inside for the actual declaration
  if node_type == "export_statement" then
    for child in node:iter_children() do
      local child_type = child:type()
      if DECLARATION_TYPES[child_type] and child_type ~= "export_statement" then
        return get_declaration_name(child, bufnr)
      end
    end
    -- Fallback: try to find a default export or re-export
    -- e.g. "export default function foo" or "export { foo }"
    local text = vim.treesitter.get_node_text(node, bufnr)
    -- Truncate to first line for display
    local first_line = text:match("^([^\n]*)")
    if #first_line > 40 then
      first_line = first_line:sub(1, 37) .. "..."
    end
    return first_line
  end

  -- For expression_statement: try to get a meaningful name
  if node_type == "expression_statement" then
    local text = vim.treesitter.get_node_text(node, bufnr)
    local first_line = text:match("^([^\n]*)")
    if #first_line > 40 then
      first_line = first_line:sub(1, 37) .. "..."
    end
    return first_line
  end

  return "[unknown]"
end

--- Get the display type for a node (handles export wrapping).
--- @param node any treesitter node
--- @return string display_type
local function get_display_type(node)
  local node_type = node:type()

  if node_type == "export_statement" then
    -- Look for the inner declaration type
    for child in node:iter_children() do
      local child_type = child:type()
      local mapped = DECLARATION_TYPES[child_type]
      if mapped and child_type ~= "export_statement" then
        return "export " .. mapped
      end
    end
    return "export"
  end

  return DECLARATION_TYPES[node_type] or node_type
end

--- Extract all top-level code points from a TypeScript buffer.
--- @param bufnr number buffer handle
--- @return table[] entries list of { name, display_type, start_row, end_row, lines }
function M.get_code_points(bufnr)
  local ft = vim.bo[bufnr].filetype
  local lang = ft == "typescriptreact" and "tsx" or "typescript"

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then
    vim.notify("CodePoints: failed to get treesitter parser for " .. lang, vim.log.levels.ERROR)
    return {}
  end

  local tree = parser:parse()[1]
  if not tree then
    vim.notify("CodePoints: failed to parse buffer", vim.log.levels.ERROR)
    return {}
  end

  local root = tree:root()
  local entries = {}

  for child in root:iter_children() do
    local node_type = child:type()

    -- Skip imports and comments
    if not SKIP_TYPES[node_type] then
      local sr, _, er, _ = child:range()
      local lines = vim.api.nvim_buf_get_lines(bufnr, sr, er + 1, false)
      local name = get_declaration_name(child, bufnr)
      local display_type = get_display_type(child)

      table.insert(entries, {
        name = name,
        display_type = display_type,
        start_row = sr,
        end_row = er,
        lines = lines,
      })
    end
  end

  return entries
end

return M
