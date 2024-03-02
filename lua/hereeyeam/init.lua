local uv = vim.uv or vim.loop

local _last_cur_line = nil
local M = {}

local default_opts = {
  min_jump = 10,
}

M.big_cursor_moved_callback = function()
  local current_win_id = vim.api.nvim_get_current_win()
  local current_win_width = vim.api.nvim_win_get_width(current_win_id)
  local current_win_col = vim.fn.wincol()
  local current_win_row = vim.fn.winline()
  local _, current_buf_col = unpack(vim.api.nvim_win_get_cursor(0))
  local col_diff = current_win_col - current_buf_col

  -- TODO: Make the shit code pretty.
  -- TODO: Smoothly decrease the hl_win width
  local hl_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "hereeyeam", { buf = hl_buf })
  local hl_win_id = vim.api.nvim_open_win(hl_buf, false, {
    relative = "win",
    width = math.min(current_win_width - col_diff + 1, (current_buf_col + 2 ^ 5) - (current_buf_col - 2 ^ 5)),
    height = 1,
    col = math.max(col_diff - 1, current_buf_col - 2 ^ 5 + col_diff - 1),
    row = current_win_row - 1,
    style = "minimal",
    focusable = false,
    noautocmd = true,
  })

  local winblend_start = 45
  local cnt = 0
  local timer = uv.new_timer()
  local width_tier = 5
  timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      if cnt == 5 then
        pcall(vim.api.nvim_win_close, hl_win_id, true)
        pcall(uv.timer_stop, timer)
        return
      end

      vim.api.nvim_set_option_value("winblend", winblend_start, { win = hl_win_id })
      cnt = cnt + 1
      winblend_start = winblend_start + 5 * cnt

      vim.api.nvim_win_set_config(hl_win_id, {
        relative = 'win',
        width = math.min(current_win_width - col_diff + 1, (current_buf_col + 2 ^ (width_tier - cnt)) - (current_buf_col - 2 ^ (width_tier - cnt)) + 1),
        height = 1,
        col = math.max(col_diff - 1, current_buf_col - 2 ^ (width_tier - cnt) + col_diff - 1),
        row = current_win_row - 1
      })

    end)
  )
end

M.setup = function(opts)
  opts = vim.tbl_deep_extend("force", default_opts, opts or {})

  local augroup = vim.api.nvim_create_augroup("HereEyeAm", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    pattern = { "*" },
    group = augroup,
    callback = function(_)
      local current_cur_line = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
      if _last_cur_line then
        local line_diff = math.abs(current_cur_line - _last_cur_line)
        if line_diff >= opts.min_jump then
          M.big_cursor_moved_callback()
        end
      end
      _last_cur_line = current_cur_line
    end,
  })
end

return M
