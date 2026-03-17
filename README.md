# WordNet.nvim

This plugin aims to be helpful as a Telescope picker for thesaurus, dictionary, and other word relation functionality using an sqlite WordNet database from https://github.com/x-englishwordnet/sqlite.

Currently it only functions as a thesaurus.

It has only been tested and confirmed working on Debian 13 and NeoVim v0.11.6.

It requires `sqlite3` to be installed on the system path.

## Installation

With lazy.nvim:

```lua
return {
  "jovielarue/wordnet.nvim",
  config = function()
    require("wordnet").setup({
      db_path = "~/.local/share/wordnet/oewn-2025-sqlite-2.3.2.sqlite"
    })

    vim.keymap.set("n", "<leader>sy", require("wordnet").pick, { desc = "WordNet Plugin" })
  end
}
```

Call by typing `<leader>sy`
