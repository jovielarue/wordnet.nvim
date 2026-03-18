local wordnet = {}

function wordnet.setup(opts)
  wordnet.config = opts or {}
end

---Runs a single sqlite3 query and returns a string array of lines of output.
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

---Fetch definitions for a word.
---Returns a string array of definitions.
---@param word string
---@return string[]
local function fetch_definition(word)
  word = word:lower():gsub("'", "''") -- SQL escape

  -- Query modified from https://github.com/x-englishwordnet/sqlite/blob/master/oewn-queries.pdf
  local sql = string.format([[
    SELECT definition
    FROM words AS sw
    LEFT JOIN senses AS s USING (wordid)
    LEFT JOIN synsets AS y USING (synsetid)
    WHERE sw.word = '%s'
    GROUP BY y.synsetid;
  ]], word)

  local lines = sqlite_query(sql)
  local results = {}

  for _, line in ipairs(lines) do
    local definition = line

    if definition and definition ~= "" then
      table.insert(results, definition)
    end
  end
  return results
end

---Fetch synonyms for a word.
---Returns a string array of synonyms.
---@param word string
---@return string[]
local function fetch_synonyms(word)
  word = word:lower():gsub("'", "''") -- SQL escape

  -- Query modified from https://github.com/x-englishwordnet/sqlite/blob/master/oewn-queries.pdf
  local sql = string.format([[
    SELECT GROUP_CONCAT(sw2.word)
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
    local synonym = line:gsub(",", ", ")

    if synonym and synonym ~= "" then
      table.insert(results, synonym)
    end
  end
  return results
end

---Open a type of vim.ui.select picker for a word.
---Type must be "synonym" or "definition"
---@param word string
---@param type string
local function show_entries_for(word, type)
  local entrylist = {}
  if type == "synonym" then
    entrylist = fetch_synonyms(word)
  else
    entrylist = fetch_definition(word)
  end

  if vim.tbl_isempty(entrylist) then
    vim.notify(
      string.format("[wordnet] No %ss found for '%s'", type, word),
      vim.log.levels.WARN
    )
    return
  end
  vim.ui.select(entrylist, {
    prompt = string.format("%ss for '%s'", type:gsub("^%l", string.upper), word),
    format_item = function(item) return item end,
  }, function(selection)
    if not selection then return end
    vim.api.nvim_put({ selection }, "c", true, true)
  end)
end

---Open a prompt asking for a word, then open the vim.ui.select for the specified type
---Type must be "synonym" or "definition"
---@param type string
function wordnet.pick(type)
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

  if type ~= "synonym" and type ~= "definition" then
    vim.notify(
      string.format(
        "Picker type %s is not valid. Please define the type as 'synonym' or 'definition' in your config.",
        type
      ),
      vim.log.levels.ERROR
    )
    return
  end

  -- Prompt the user for a word (non-blocking vim.ui.input)
  vim.ui.input({ prompt = "Word: " }, function(input)
    if not input or input == "" then return end

    vim.schedule(function()
      show_entries_for(vim.trim(input), type)
    end)
  end)
end

return wordnet
