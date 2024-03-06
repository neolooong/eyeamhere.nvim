local uv = vim.uv or vim.loop

local _last_cur_line = nil
local M = {}

local default_opts = {
  min_jump = 10,
  width = 64,
  interval_ms = 15,
  total_ms = 350,
  base_blend = 50,
  end_blend = 80,
  highlight = { link = "Normal" },
}

M.big_cursor_moved_callback = function()
  local get_hl_win_config = function(leftmost, rightmost, current_col, current_row, width)
    local hl_win_col_start = math.max(leftmost, current_col - width)
    local hl_win_col_end = math.min(rightmost, current_col + width)
    local hl_win_width = hl_win_col_end - hl_win_col_start + 1
    return {
      relative = "win",
      width = hl_win_width,
      height = 1,
      col = hl_win_col_start - 1,
      row = current_row - 1,
    }
  end

  local get_width = function(width, total_ms, elapsed_ms)
    return vim.fn.round(math.min(-math.log(elapsed_ms / total_ms, 10), 1) * width)
  end

  local get_blend = function(base_blend, end_blend, total_ms, elapsed_ms)
    local range = end_blend - base_blend
    return base_blend + range - vim.fn.round(math.min(-math.log(elapsed_ms / total_ms, 10), 1) * range)
  end

  local current_win_id = vim.api.nvim_get_current_win()
  local current_win_width = vim.api.nvim_win_get_width(current_win_id)
  local current_win_col = vim.fn.wincol()
  local current_win_row = vim.fn.winline()
  local win_buf_offset = vim.fn.getwininfo(current_win_id)[1].textoff
  local buf_leftmost, buf_rightmost = win_buf_offset + 1, current_win_width

  local hl_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "HereEyeAm", { buf = hl_buf })
  local timer = uv.new_timer()
  local hl_win_id
  local elapsed_ms = 0

  timer:start(
    0,
    M.opts.interval_ms,
    vim.schedule_wrap(function()
      -- Callback might be scheduled before timer is actually closed.
      if not uv.is_active(timer) then
        return
      end

      local should_close = elapsed_ms >= M.opts.total_ms

      local width = get_width(vim.fn.round(M.opts.width / 2), M.opts.total_ms, elapsed_ms)
      local blend = get_blend(M.opts.base_blend, M.opts.end_blend, M.opts.total_ms, elapsed_ms)
      local hl_win_config = get_hl_win_config(buf_leftmost, buf_rightmost, current_win_col, current_win_row, width)

      if hl_win_id == nil then
        hl_win_id = vim.api.nvim_open_win(
          hl_buf,
          false,
          vim.tbl_deep_extend("force", {
            style = "minimal",
            focusable = false,
            noautocmd = true,
          }, hl_win_config)
        )
        vim.api.nvim_win_set_hl_ns(hl_win_id, vim.api.nvim_create_namespace("HereEyeAm"))
      end

      vim.api.nvim_set_option_value("winblend", blend, { win = hl_win_id })
      vim.api.nvim_win_set_config(hl_win_id, hl_win_config)

      if should_close then
        vim.api.nvim_win_close(hl_win_id, true)
        uv.timer_stop(timer)
        uv.close(timer)
        return
      end

      elapsed_ms = elapsed_ms + M.opts.interval_ms
    end)
  )
end

M.setup = function(opts)
  M.opts = vim.tbl_deep_extend("force", default_opts, opts or {})

  local ns_id = vim.api.nvim_create_namespace("HereEyeAm")
  vim.api.nvim_set_hl(ns_id, "NormalFloat", M.opts.highlight)

  local augroup = vim.api.nvim_create_augroup("HereEyeAm", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    pattern = { "*" },
    group = augroup,
    callback = function(_)
      local current_cur_line = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
      if _last_cur_line then
        local line_diff = math.abs(current_cur_line - _last_cur_line)
        if line_diff >= M.opts.min_jump then
          M.big_cursor_moved_callback()
        end
      end
      _last_cur_line = current_cur_line
    end,
  })
end

return M
