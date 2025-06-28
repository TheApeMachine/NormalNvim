-- AI Assistant for Neovim
local M = {}

-- Health check support
M.health = require('ai.health')

-- Load all modules
local modules = {
  'ai.config',
  'ai.context', 
  'ai.llm',
  'ai.edit',
  'ai.refactor',
  'ai.search',
  'ai.embeddings',
  'ai.planner',
  'ai.commands',
  'ai.chat',
  'ai.multifile',
  'ai.testing',
  'ai.debug',
  'ai.websearch',
  'ai.tools',
}

for _, module in ipairs(modules) do
  local ok, err = pcall(require, module)
  if not ok then
    vim.notify('Failed to load ' .. module .. ': ' .. err, vim.log.levels.ERROR)
  end
end

-- Export modules
M.config = require('ai.config')
M.context = require('ai.context')
M.llm = require('ai.llm')
M.edit = require('ai.edit')
M.refactor = require('ai.refactor')
M.search = require('ai.search')
M.planner = require('ai.planner')
M.embeddings = require('ai.embeddings')
M.chat = require('ai.chat')
M.multifile = require('ai.multifile')
M.testing = require('ai.testing')
M.debug = require('ai.debug')
M.websearch = require('ai.websearch')
M.tools = require('ai.tools')
M.commands = require('ai.commands')

-- Initialize the module
function M.setup(opts)
  -- Merge user options with defaults
  M.config.setup(opts)
  
  -- Setup planner
  M.planner.setup()
  
  -- Setup commands
  M.commands.setup()
  
  -- Initialize search index if enabled
  local search = require('ai.search')
  if M.config.get().search.index_on_startup then
    vim.defer_fn(function()
      search.index_workspace()
    end, 1000) -- Wait 1 second after startup
  end
  
  -- Set up autocommands
  local context = require('ai.context')
  vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI", "BufEnter"}, {
    group = vim.api.nvim_create_augroup("AIContext", { clear = true }),
    callback = function()
      -- Update cursor context in the background
      vim.defer_fn(function()
        context.update_cursor_context()
      end, 100) -- Small delay to avoid too frequent updates
    end,
  })
  
  vim.notify("AI Assistant initialized", vim.log.levels.INFO)
end

return M 