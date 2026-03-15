if vim.g.loaded_code_points then
  return
end
vim.g.loaded_code_points = true

vim.api.nvim_create_user_command("CodePoints", function()
  require("code-points").run()
end, {
  nargs = 0,
  desc = "Open code points window to view and reorder top-level declarations",
})
