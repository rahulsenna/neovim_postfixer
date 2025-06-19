-- postfixer.nvim - A Neovim plugin for postfix completions
-- Converted from VS Code extension

local M = {}

-- Global state
local config_file = ""
local postfixes = {}
local user_config = {
  fallback_command = "<Tab>",
  config_path = nil
}

-- Constants
local FIX_RE = "^(%s*)(.+)%.(%w+)$"
local VAR_CURSOR = "$cursor"
local VAR_INDENT = "%$%-%->"
local VAR_WHOLE = "%$0"
local indent_str = "\t"

-- Utility functions
local function file_exists(path)
  local f = io.open(path, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local function write_file(path, content)
  local file = io.open(path, "w")
  if not file then
    return false
  end
  file:write(content)
  file:close()
  return true
end
local lyaml = require("lyaml")
-- YAML parser (simple implementation)


-- Initialize postfixes from config file
local function init_fixes()
  
  local f = assert(io.open(config_file, "r"))
  local content = f:read("*a")
  
  f:close()

-- Parse YAML
  postfixes = lyaml.load(content)

  -- Handle space-separated scopes
  local new_postfixes = {}
  for scopes, fixes in pairs(postfixes) do
    for scope in scopes:gmatch("%S+") do
      new_postfixes[scope] = fixes
    end
  end
  
  -- Copy back
  for scope, fixes in pairs(new_postfixes) do
    postfixes[scope] = fixes
  end
  
  return true
end

-- Get postfix transformation
local function get_fix(fixes, line)
  local indent, target, cmd = line:match(FIX_RE)
  if not indent or not target or not cmd then
    error("Could not parse line")
  end
  
  -- Find matching fix
  local fix = nil
  for _, f in ipairs(fixes) do
    if f.cmd == cmd then
      fix = f
      break
    end
  end
  
  if not fix then
    error("no fix: " .. cmd)
  end
  
  fix.target = fix.target
    :gsub("\\w", "%%w")
    :gsub("\\W", "[^%%w]")
    :gsub("\\d", "%%d")
    :gsub("\\D", "[^%%d]")
    :gsub("\\s", "%%s")
    :gsub("\\S", "%%S")
  
  -- Handle line mode
  if not fix.line then
    local match = target:match(fix.target .. "$")
    print("target", target, fix.target, match)

    if not match then
      error("no match: " .. target)
    end
    target = match
  end
  
  -- Match target pattern
  local target_match = {target:match(fix.target)}
  if #target_match == 0 then
    error("No match for target: " .. target)
  end
  
  -- Process fix template
  local parsed = fix.fix:gsub("\n$", "")
  parsed = parsed:gsub(VAR_WHOLE, target_match[1] or target)
  parsed = parsed:gsub(VAR_INDENT, indent_str)
  
  -- Replace capture groups
  for i, match in ipairs(target_match) do
    parsed = parsed:gsub("%$" .. i, match)
  end
  
  -- Process output lines
  local lines = {}
  for line_text in parsed:gmatch("[^\r\n]+") do
    if fix.line then
      table.insert(lines, indent .. line_text)
    else
      table.insert(lines, line_text)
    end
  end
  local output = table.concat(lines, "\n")
  
  -- Handle cursor position
  local cursor = {line = 0, character = 0}
  if output:find(VAR_CURSOR) then
    local line_num = 0
    for line_text in output:gmatch("[^\r\n]+") do
      if line_text:find(VAR_CURSOR) then
        cursor.line = line_num
        cursor.character = line_text:find(VAR_CURSOR) - 1
        if not fix.line then
          local after_cursor = line_text:match(VAR_CURSOR .. "(.*)")
          cursor.character = -#after_cursor
        end
        print("cursor.character", cursor.character)
        break
      end
      line_num = line_num + 1
    end
    output = output:gsub(VAR_CURSOR, "")
  else
    cursor.character = #output
  end
  
  return {
    output = output,
    cursor = cursor,
    line = fix.line or false,
    replace_reg = fix.target .. "%.%w+$",
    len = #cmd + 1 + #target
  }
end

-- Main fix command
local function fix_postfix()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor_pos[1]
  local col_num = cursor_pos[2]
  
  -- Get current line text up to cursor
  local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
  local text = line:sub(1, col_num)
  
  local fixes = postfixes[filetype]

  if not fixes then
    user_config.fallback_command()
    return
  end
  
  local success, fix = pcall(get_fix, fixes, text)
  if not success then
    user_config.fallback_command()
    return
  end
  
  local replace_start_col = 0
  local replace_end_col = col_num
  
  if not fix.line then
      replace_start_col = col_num - fix.len
  end
  
  -- Apply the fix
  vim.api.nvim_buf_set_text(bufnr, line_num - 1, replace_start_col, line_num - 1, replace_end_col, vim.split(fix.output, "\n"))
  
  -- Set cursor position
  local new_line = line_num -1 + fix.cursor.line
  local new_col = fix.cursor.character
  if not fix.line then
    new_col = replace_start_col + #fix.output + fix.cursor.character
  end
  
  vim.api.nvim_win_set_cursor(0, {new_line + 1, math.max(0, new_col)})
end

-- Reload configuration
local function reload_config()
  init_fixes()
  print("Postfixer configuration reloaded")
end

-- Edit configuration
local function edit_config()
  vim.cmd("edit " .. config_file)
end

-- Setup function
function M.setup(opts)
  opts = opts or {}
  
  -- Set config file path
  local data_path = vim.fn.stdpath("data")
  config_file = opts.config_path or (data_path .. "/postfixer/config.yml")
  user_config.fallback_command = opts.fallback_command or "<Tab>"
  
  -- Create config directory if it doesn't exist
  local config_dir = vim.fn.fnamemodify(config_file, ":h")
  vim.fn.mkdir(config_dir, "p")
  
  -- Create default config if it doesn't exist
  if not file_exists(config_file) then
    local default_config = [[
c cpp:
  - cmd: log
    target: (.+)
    fix: console.log($1)
    line: false
  - cmd: if
    target: (.+)
    fix: if ($1) {$cursor}
    line: true

javascript typescript:
  - cmd: log
    target: (.+)
    fix: console.log($1)
    line: false
  - cmd: if
    target: (.+)
    fix: if ($1) {$cursor}
    line: true

python:
  - cmd: print
    target: (.+)
    fix: print($1)
    line: false
  - cmd: len
    target: (.+)
    fix: len($1)
    line: false

lua:
  - cmd: print
    target: (.+)
    fix: print($1)
    line: false
  - cmd: req
    target: (.+)
    fix: require('$1')
    line: false
]]
    write_file(config_file, default_config)
  end
  
  -- Initialize postfixes
  init_fixes()
  
  -- Create commands
  vim.api.nvim_create_user_command("PostfixerFix", fix_postfix, {})
  vim.api.nvim_create_user_command("PostfixerReload", reload_config, {})
  vim.api.nvim_create_user_command("PostfixerEdit", edit_config, {})
  
  -- Set up key mapping (optional)
  if opts.keymap ~= false then
    local key = opts.keymap or "<C-j>"
    vim.keymap.set("i", key, fix_postfix, { desc = "Postfixer: Apply postfix completion" })
  end
end

return M