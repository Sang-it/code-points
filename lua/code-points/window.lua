local reorder = require("code-points.reorder")

local M = {}

--- Build display lines from code point entries.
--- Format: "type name [L<line>]"
--- @param entries table[] list of code point entries from treesitter module
--- @return string[] display_lines
local function build_display_lines(entries)
  local lines = {}
  for _, entry in ipairs(entries) do
    local display = entry.display_type .. " " .. entry.name .. " [L" .. (entry.start_row + 1) .. "]"
    table.insert(lines, display)
  end
  return lines
end

--- Create a centered floating window.
--- @param buf number buffer handle
--- @param title string window title
--- @return number win window handle
local function open_centered_float(buf, title)
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  return win
end

--- Open the code points floating window.
--- @param source_bufnr number the source buffer to operate on
--- @param entries table[] list of code point entries from treesitter module
function M.open(source_bufnr, entries)
  -- Create a scratch buffer with acwrite so :w triggers BufWriteCmd
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })

  -- Populate the buffer with display lines
  local display_lines = build_display_lines(entries)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)

  -- Mark the buffer as unmodified after initial population
  vim.api.nvim_set_option_value("modified", false, { buf = buf })

  -- Give it a name so :w doesn't complain about no file name
  vim.api.nvim_buf_set_name(buf, "code-points://reorder")

  -- Open the float
  local win = open_centered_float(buf, "Code Points")

  -- Map 'q' to close the window (normal mode)
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, noremap = true, silent = true, desc = "Close Code Points window" })

  -- Handle :w — intercept the save and apply reordering
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      -- Filter out empty lines
      local filtered = {}
      for _, line in ipairs(new_lines) do
        local trimmed = vim.trim(line)
        if trimmed ~= "" then
          table.insert(filtered, trimmed)
        end
      end

      local ok, err = reorder.apply(source_bufnr, entries, filtered)
      if ok then
        vim.api.nvim_set_option_value("modified", false, { buf = buf })
        vim.notify("CodePoints: reorder applied", vim.log.levels.INFO)

        -- Close the window after successful save
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      else
        vim.notify("CodePoints: " .. (err or "unknown error"), vim.log.levels.ERROR)
      end
    end,
  })

  -- Cleanup buffer when window is closed
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end,
  })
end

return M
