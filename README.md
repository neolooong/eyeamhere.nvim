# hereeyeam.nvim

Highlight the current line whenever the cursor moves across multiple lines. Eyes can always quickly and easily focus on the cursor.

https://github.com/neolooong/hereeyeam.nvim/assets/32055974/be6f9640-5dfb-4524-85f7-03f29e00d46d

Note: This plugin only tested on nightly build (neovim 0.10).

## Installation

Using `lazy.nvim`:

```lua
{
  "neolooong/hereeyeam.nvim",
  opts = {},
}
```

## Usage

This plugin provide the following options and default value:

```lua
require('hereeyeam').setup(
  {
    -- whether enable the highlight effect
    enable = true,
    -- the minimal lines acrossed, show highlight effect
    min_jump = 10,
    -- initial width (not include the cursor
    size = 80,
    -- how often to recalcute the width and winblend
    interval_ms = 15,
    -- how long the effect took
    total_ms = 350,
    -- the start value of blend value increased
    base_blend = 50,
    -- the end valud of blend value
    end_blend = 80,
    -- Custom the color of the highlight effect
    highlight = { link = "Normal" },
    -- ignore on specific buftypes
    ignore_buftype = {},
    -- ignore on specific filetypes
    ignore_filetype = {},
  }
)
```

To highlight on current line:

```lua
require('hereeyeam').show()
```

To enable/disable the highlight effect:

```lua
require('hereeyeam').toggle()
require('hereeyeam').enable()
require('hereeyeam').disable()
```

## Similar plugin

- https://github.com/DanilaMihailov/beacon.nvim
- https://github.com/edluffy/specs.nvim
