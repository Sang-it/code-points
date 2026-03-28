if vim.g.loaded_fluoride then
  return
end
vim.g.loaded_fluoride = true

local valid_modes = { float = true, vsplit = true, split = true }

vim.api.nvim_create_user_command("Fluoride", function(cmd)
  local arg = cmd.args ~= "" and cmd.args or nil
  if arg then
    if not valid_modes[arg] then
      vim.notify("Fluoride: invalid mode '" .. arg .. "'. Use float, vsplit, or split.", vim.log.levels.WARN)
      return
    end
    require("fluoride").run({ mode = arg })
  else
    require("fluoride").run()
  end
end, {
  nargs = "?",
  complete = function() return { "float", "vsplit", "split" } end,
  desc = "Open Fluoride window (optional: float, vsplit, split)",
})

vim.api.nvim_create_user_command("FluorideToggle", function()
  require("fluoride").toggle()
end, {
  nargs = 0,
  desc = "Toggle Fluoride window",
})
