local uv = vim.uv or vim.loop

local _hl_buf_id = nil
local _hl_win_id = nil
local _last_cur_line = nil
local _timer = nil
local M = {}

local default_opts = {
  min_jump = 10,
  width = 64,
  interval_ms = 15,
  total_ms = 350,
  base_blend = 50,
  end_blend = 80,
  highlight = { link = "Normal" },
  ignore_buftype = {},
  ignore_filetype = {},
}

M.big_cursor_moved_callback = function()
  if vim.fn.index(M.opts.ignore_buftype, vim.api.nvim_get_option_value("buftype", { buf = 0 })) ~= -1 then
    return
  end

  if vim.fn.index(M.opts.ignore_filetype, vim.api.nvim_get_option_value("filetype", { buf = 0 })) ~= -1 then
    return
  end

  local get_hl_win_config = function(leftmost, rightmost, current_col, current_row, width)
    local hl_win_col_start = math.max(leftmost, current_col - width)
    local hl_win_col_end = math.min(rightmost, current_col + width)
    local hl_win_width = hl_win_col_end - hl_win_col_start + 1
    return {
      relative = "editor",
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
  local current_wininfo = vim.fn.getwininfo(current_win_id)[1]
  local current_win_col = vim.fn.wincol() + current_wininfo.wincol - 1
  local current_win_row = vim.fn.winline() + current_wininfo.winrow - 1
  local buf_leftmost = current_wininfo.textoff + current_wininfo.wincol
  local buf_rightmost = current_wininfo.wincol + current_wininfo.width - 1
  if _hl_buf_id == nil then
    _hl_buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("filetype", "HereEyeAm", { buf = _hl_buf_id })
  end

  -- reuse window, create new timer
  local hl_win_id
  if _hl_win_id then
    hl_win_id = _hl_win_id
  end

  if _timer ~= nil then
    uv.timer_stop(_timer)
  end
  _timer = uv.new_timer()

  local elapsed_ms = 0
  local timer = _timer

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
          _hl_buf_id,
          false,
          vim.tbl_deep_extend("force", {
            style = "minimal",
            focusable = false,
            noautocmd = true,
          }, hl_win_config)
        )
        vim.api.nvim_win_set_hl_ns(hl_win_id, vim.api.nvim_create_namespace("HereEyeAm"))
        _hl_win_id = hl_win_id
      end

      vim.api.nvim_set_option_value("winblend", blend, { win = hl_win_id })
      vim.api.nvim_win_set_config(hl_win_id, hl_win_config)

      if should_close then
        vim.api.nvim_win_close(hl_win_id, true)
        _hl_win_id = nil
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
