-- AI Assistant for Neovim
local M = {}

-- Load sub-modules
M.config = require("ai.config")
M.context = require("ai.context")
M.llm = require("ai.llm")
M.edit = require("ai.edit")
M.refactor = require("ai.refactor")
M.search = require("ai.search")
M.commands = require("ai.commands")
M.planner = require("ai.planner")

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
  
  vim.notify("AI Assistant initialized", vim.log.levels.INFO)
end

return M 