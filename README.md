

https://github.com/user-attachments/assets/0712cfea-e908-47d7-96c8-46562d26cb4f

---

# Installation Instructions for `postfixer.lua`

## 📁 File Placement

**Place the plugin file:**

   Copy `postfixer.lua` to your Neovim configuration directory, for example:

   ```bash
   mkdir -p ~/.config/nvim/lua
   cp postfixer.lua ~/.config/nvim/lua/postfixer.lua
   ```

## 🛠 Usage

In your Neovim `init.lua` or appropriate config, load the plugin like this:

```lua
require("postfixer").setup({
      keymap = "<C-p>",  -- Key to trigger postfix completion
      fallback_command = autocomplete,  -- Fallback when no postfix matches
      config_path = nil,  -- Custom config file path (optional)
    })
```

---
I've supplied my config file `config.yml`

## 🧪 Example `config.yml`

```yaml
python:
  # Print
  - cmd: "pr"
    line: true
    target: ".+"
    fix: |
      print("$0:$cursor ", $0)
```

## 🧩 Dependencies

This plugin requires [LuaRocks](https://luarocks.org/) and the `lyaml` library for YAML parsing.

### Install `lyaml` via LuaRocks:

```bash
luarocks install lyaml
```

> Ensure `luarocks` is installed and available in your system's `PATH`.
> If you're using a custom Lua version (e.g., from Homebrew), make sure `luarocks` is set up for that version.

---