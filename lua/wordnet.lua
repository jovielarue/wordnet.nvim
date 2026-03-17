local wordnet = {}

function wordnet.setup(opts)
  wordnet.config = opts or {}
end

---Runs a single sqlite3 query and return lines of output.
---@param sql string
---@return string[]
local function sqlite_query(sql)
  local cmd = string.format(
    "sqlite3 %s %s",
    vim.fn.shellescape(vim.fn.expand(wordnet.config.db_path)),
    vim.fn.shellescape(sql)
  )

  local handle = io.popen(cmd)
  if not handle then return {} end
  local result = handle:read("*a")
  handle:close()

  if not result or result == "" then return {} end

  local lines = {}
  for line in result:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  return lines
end

---Fetch synonyms for a word.
---Returns a list of { synonym, definition } tables.
---@param word string
---@return table[]
local function fetch_synonyms(word)
  word = word:lower():gsub("'", "''") -- SQL escape

  -- Query modified from https://github.com/x-englishwordnet/sqlite/blob/master/oewn-queries.pdf
  local sql = string.format([[
    SELECT sw2.word, definition
    FROM words AS sw
    LEFT JOIN senses AS s USING (wordid)
    LEFT JOIN synsets AS y USING (synsetid)
    LEFT JOIN senses AS s2 ON (y.synsetid = s2.synsetid)
    LEFT JOIN words AS sw2 ON (sw2.wordid = s2.wordid)
    WHERE sw.word = '%s'
    AND sw.wordid <> sw2.wordid GROUP BY y.synsetid;
  ]], word)

  local lines = sqlite_query(sql)
  local results = {}

  for _, line in ipairs(lines) do
    local synonym, definition = line:match("([^|]+)|(.*)")

    if synonym and synonym ~= "" and definition and definition ~= "" then
      table.insert(results, {
        synonym = synonym,
        definition = definition,
      })
    end
  end
  return results
end

---Set up and open up the Telescope picker for a specific word
---@param word string
local function make_picker(word)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local synonyms = fetch_synonyms(word)

  if vim.tbl_isempty(synonyms) then
    vim.notify(
      string.format("[wordnet] No synonyms found for '%s'", word),
      vim.log.levels.WARN
    )
    return
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 24 },       -- synonym
      { remaining = true }, -- definition
    }
  })

  local function make_display(entry)
    return displayer({
      { entry.value.synonym,    "TelescopeResultsIdentifier" },
      { entry.value.definition, "TelescopeResultsComment" },
    })
  end

  pickers.new({}, {
    prompt_title = string.format("Synonyms for %s", word),

    finder = finders.new_table({
      results = synonyms,
      entry_maker = function(item)
        return {
          value = item,
          display = make_display,
          ordinal = item.synonym .. " " .. item.definition,
        }
      end,
    }),

    sorter = conf.generic_sorter({}),

    attach_mappings = function(prompt_bufnr, map)
      -- <CR> - insert the synonym at cursor position
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          vim.api.nvim_put({ selection.value.synonym }, "c", true, true)
        end
      end)

      -- <C-y> - yank synonym to the unnamed register without inserting
      map("i", "<C-y>", function()
        local selection = action_state.get_selected_entry()
        if selection then
          vim.fn.setreg('"', selection.value.synonym)
          vim.notify(
            string.format("[wordnet] Yanked '%s'", selection.value.synonym),
            vim.log.levels.INFO
          )
        end
      end)

      return true
    end,
  }):find()
end

---Open a prompt asking for a word, then open the synonym Telescope picker.
function wordnet.pick()
  -- Verify db exists
  if vim.fn.filereadable(vim.fn.expand(wordnet.config.db_path)) == 0 then
    vim.notify(
      string.format(
        "[wordnet] Database not found: %s\nSet db_path with require('wordnet').setup({ db_path = '...' })",
        wordnet.config.db_path
      ),
      vim.log.levels.ERROR
    )

    return
  end

  -- Prompt the user for a word (non-blocking vim.ui.input)
  vim.ui.input({ prompt = "Word: " }, function(input)
    if not input or input == "" then return end

    vim.schedule(function()
      make_picker(vim.trim(input))
    end)
  end)
end

return wordnet
