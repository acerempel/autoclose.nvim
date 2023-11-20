local autoclose = {}

autoclose.config = {
   keys = {
      ["("] = { escape = false, close = true, pair = "()" },
      ["["] = { escape = false, close = true, pair = "[]" },
      ["{"] = { escape = false, close = true, pair = "{}" },

      [">"] = { escape = true, close = false, pair = "<>" },
      [")"] = { escape = true, close = false, pair = "()" },
      ["]"] = { escape = true, close = false, pair = "[]" },
      ["}"] = { escape = true, close = false, pair = "{}" },

      ['"'] = { escape = true, close = true, pair = '""' },
      ["'"] = { escape = true, close = true, pair = "''" },
      ["`"] = { escape = true, close = true, pair = "``" },

      [" "] = { escape = false, close = true, pair = "  " },

      ["<BS>"] = {},
      ["<C-H>"] = {},
      ["<C-W>"] = {},
      ["<CR>"] = { disable_command_mode = true },
      ["<S-CR>"] = { disable_command_mode = true },
   },
   options = {
      disabled_filetypes = { "text" },
      disable_when_touch = false,
      touch_regex = "[%w(%[{]",
      pair_spaces = false,
      auto_indent = true,
      disable_command_mode = false,
   },
   disabled = false,
}

local config = autoclose.config

local function insert_get_pair()
   -- add "_" to let close function work in the first col
   local line = "_" .. vim.api.nvim_get_current_line()
   local col = vim.api.nvim_win_get_cursor(0)[2] + 1

   return line:sub(col, col + 1)
end

local function command_get_pair()
   -- add "_" to let close function work in the first col
   local line = "_" .. vim.fn.getcmdline()
   local col = vim.fn.getcmdpos()

   return line:sub(col, col + 1)
end

local function is_pair(pair)
   if pair == "  " then
      return false
   end

   for _, info in pairs(config.keys) do
      if pair == info.pair then
         return true
      end
   end
   return false
end

local function handler(key, info, mode)
   if config.disabled then
      return key
   end

   local pair = mode == "insert" and insert_get_pair() or command_get_pair()

   if (key == "<BS>" or key == "<C-H>" or key == "<C-W>") and is_pair(pair) then
      return "<BS><Del>"
   elseif
      mode == "insert"
      and (key == "<CR>" or key == "<S-CR>")
      and is_pair(pair)
   then
      return "<CR><ESC>O" .. (config.options.auto_indent and "" or "<C-D>")
   elseif info.escape and pair:sub(2, 2) == key then
      return mode == "insert" and "<C-G>U<Right>" or "<Right>"
   elseif info.close then
      -- disable if the cursor touches alphanumeric character
      if
         config.options.disable_when_touch
         and (pair .. "_"):sub(2, 2):match(config.options.touch_regex)
      then
         return key
      end

      -- don't pair spaces
      if
         key == " "
         and (
            not config.options.pair_spaces
            or (config.options.pair_spaces and not is_pair(pair))
            or pair:sub(1, 1) == pair:sub(2, 2)
         )
      then
         return key
      end

      return info.pair .. (mode == "insert" and "<C-G>U<Left>" or "<Left>")
   else
      return key
   end
end

local function setup_filetype()
   local bufnr = vim.api.nvim_get_current_buf()
   local current_filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

   -- Are we globally disabled for this filetype?
   if vim.tbl_contains(config.options.disabled_filetypes, current_filetype) then
      return
   end

   for key, info in pairs(config.keys) do
      local ft_disabled =
         -- Is this pair explicitly enabled for this filetype? (No enabled
         -- list means enabled everywhere)
         (info.enabled_filetypes and not vim.tbl_contains(info.enabled_filetypes, current_filetype))
         -- Is this pair disabled for this filetype?
         or vim.tbl_contains(info.disabled_filetypes or {}, current_filetype)

      if not ft_disabled then
         vim.keymap.set("i", key, function()
            return (key == " " and "<C-]>" or "") .. handler(key, info, "insert")
         end, { noremap = true, expr = true, buffer = bufnr })
      end
   end
end

function autoclose.setup(user_config)
   config = vim.tbl_deep_extend('force', config, user_config or {})

   local augroup = vim.api.nvim_create_augroup('autoclose', {})
   vim.api.nvim_create_autocmd('FileType', {
      callback = setup_filetype,
      group = augroup,
      pattern = "*",
      desc = "Set up buffer-local mappings for autoclose",
   })

   for key, info in pairs(config.keys) do
      if
         not config.options.disable_command_mode
         and not info.disable_command_mode
      then
         vim.keymap.set("c", key, function()
            return (key == " " and "<C-]>" or "")
               .. handler(key, info, "command")
         end, { noremap = true, expr = true })
      end
   end
end

function autoclose.toggle()
   config.disabled = not config.disabled
end

return autoclose
