# WordNet.nvim

This plugin is a thesaurus and dictionary picker which uses a local sqlite WordNet database from https://github.com/x-englishwordnet/sqlite.

It has only been tested and confirmed working on Debian 13 and Neovim v0.11.6.

It requires `sqlite3` to be installed on the system path.

## Installation

With lazy.nvim:

```lua
return {
  "jovielarue/wordnet.nvim",
  config = function()
    require("wordnet").setup({ db_path = "~/.local/share/wordnet/oewn-2025-sqlite-2.3.2.sqlite" })

    vim.keymap.set("n", "<leader>ws", function() require("wordnet").pick("synonym") end, { desc = "WordNet Synonyms" })
    vim.keymap.set("n", "<leader>wd", function() require("wordnet").pick("definition") end, { desc = "WordNet Definitions" })
  end
}
```

Download and unzip the WordNet database from https://github.com/x-englishwordnet/sqlite/blob/master/oewn-2025-sqlite-2.3.2.sqlite.zip.

Put the database in a location accessible from your Neovim config. As shown above, I put it in `~/.local/share/wordnet`. Ensure the path to the database on your system matches the one in your config.

## Usage

Call by typing `<leader>ws` for synonyms or `<leader>wd` for definitions.
