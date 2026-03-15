local M = {}

M.config = {}

--- Setup the plugin with user configuration.
--- @param user_config? table
function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

--- Open the code points floating window for the current buffer.
function M.run()
  local source_bufnr = vim.api.nvim_get_current_buf()
  local treesitter = require("code-points.treesitter")

  local entries, lang = treesitter.get_code_points(source_bufnr)

  if not lang then
    return
  end

  if #entries == 0 then
    vim.notify("CodePoints: no top-level declarations found", vim.log.levels.INFO)
    return
  end

  local window = require("code-points.window")
  window.open(source_bufnr, entries, lang)
end

return M
