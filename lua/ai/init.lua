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
  'ai.planner',
  'ai.commands',
}

for _, module in ipairs(modules) do
  local ok, err = pcall(require, module)
  if not ok then
    vim.notify('Failed to load ' .. module .. ': ' .. err, vim.log.levels.ERROR)
  end
end

-- Initialize the module
function M.setup(opts)
  -- Merge user options with defaults
  M.config.setup(opts)
  
  -- Setup planner
  M.planner.setup()
  
  -- Setup commands
  M.commands.setup()
  
  -- Don't auto-index on startup to avoid fast event context issues
  -- Users can manually trigger indexing with <leader>aI
  if M.config.get().search.auto_index then
    -- Defer indexing to avoid startup issues
    vim.defer_fn(function()
      M.search.index_workspace()
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