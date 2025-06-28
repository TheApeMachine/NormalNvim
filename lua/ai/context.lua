-- Tree-sitter based Context Extraction
-- Provides intelligent context extraction using AST analysis

local M = {}
local ts = vim.treesitter
local parsers = require("nvim-treesitter.parsers")
local queries = require("nvim-treesitter.query")
local ts_utils = require("nvim-treesitter.ts_utils")

-- Cache for parsed contexts
M._cache = {}
M._cursor_context = nil

-- Common node types for different languages
M.node_types = {
  function_like = {
    "function_declaration", "function_definition", "method_definition",
    "arrow_function", "function_expression", "lambda_expression",
    "method_declaration", "constructor_declaration", "function_item"
  },
  class_like = {
    "class_declaration", "class_definition", "interface_declaration",
    "struct_declaration", "struct_item", "impl_item", "trait_item"
  },
  import_like = {
    "import_statement", "import_declaration", "import_from_statement",
    "use_declaration", "require_statement", "include_statement"
  },
  comment_like = {
    "comment", "line_comment", "block_comment", "documentation_comment"
  }
}

-- Get the current buffer's parser
function M.get_parser(bufnr)
  bufnr = bufnr or 0
  if not parsers.has_parser() then
    return nil
  end
  return parsers.get_parser(bufnr)
end

-- Find the node at cursor position
function M.get_node_at_cursor(winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr or 0)
  local row, col = cursor[1] - 1, cursor[2]
  
  local parser = M.get_parser()
  if not parser then 
    vim.notify("No Tree-sitter parser available for this buffer", vim.log.levels.WARN)
    return nil 
  end
  
  local trees = parser:parse()
  if not trees or #trees == 0 then
    vim.notify("Failed to parse buffer with Tree-sitter", vim.log.levels.ERROR)
    return nil
  end
  
  local tree = trees[1]
  if not tree then return nil end
  
  local root = tree:root()
  if not root then return nil end
  
  return root:descendant_for_range(row, col, row, col)
end

-- Find parent node of specific types
function M.find_parent_node(node, node_types)
  if not node then return nil end
  
  local parent = node:parent()
  while parent do
    if vim.tbl_contains(node_types, parent:type()) then
      return parent
    end
    parent = parent:parent()
  end
  
  return nil
end

-- Extract text from a node with bounds checking
function M.get_node_text(node, bufnr)
  if not node then return "" end
  
  bufnr = bufnr or 0
  
  -- Check if node has the range method
  if not node.range then return "" end
  
  local start_row, start_col, end_row, end_col = node:range()
  
  -- Get lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  if #lines == 0 then return "" end
  
  -- Handle single line
  if start_row == end_row then
    lines[1] = string.sub(lines[1], start_col + 1, end_col)
  else
    -- Handle multi-line
    lines[1] = string.sub(lines[1], start_col + 1)
    if #lines > 1 then
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  end
  
  return table.concat(lines, "\n")
end

-- Extract imports from the buffer
function M.extract_imports(bufnr, max_lines)
  bufnr = bufnr or 0
  max_lines = max_lines or 50
  
  local parser = M.get_parser(bufnr)
  if not parser then return {} end
  
  local tree = parser:parse()[1]
  if not tree then return {} end
  
  local imports = {}
  local root = tree:root()
  
  -- Use Tree-sitter query to find imports
  local lang = parsers.get_buf_lang(bufnr)
  local query_string = ""
  
  -- Language-specific queries
  if lang == "python" then
    query_string = [[
      (import_statement) @import
      (import_from_statement) @import
    ]]
  elseif lang == "javascript" or lang == "typescript" or lang == "tsx" then
    query_string = [[
      (import_statement) @import
      (import_declaration) @import
    ]]
  elseif lang == "rust" then
    query_string = [[
      (use_declaration) @import
    ]]
  elseif lang == "go" then
    query_string = [[
      (import_declaration) @import
    ]]
  else
    -- Fallback: search for import-like nodes
    for child in root:iter_children() do
      if child:start() > max_lines then break end
      
      for _, import_type in ipairs(M.node_types.import_like) do
        if child:type() == import_type then
          table.insert(imports, M.get_node_text(child, bufnr))
          break
        end
      end
    end
    return imports
  end
  
  -- Execute query
  local ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
  if ok and query then
    for _, match, _ in query:iter_matches(root, bufnr, 0, max_lines) do
      for _, node in pairs(match) do
        if node then
          local text = M.get_node_text(node, bufnr)
          if text and text ~= "" then
            table.insert(imports, text)
          end
        end
      end
    end
  end
  
  return imports
end

-- Extract documentation comments
function M.extract_documentation(node, bufnr)
  if not node then return nil end
  
  bufnr = bufnr or 0
  local start_row = node:start()
  
  -- Look for comments immediately before the node
  local doc_lines = {}
  for row = start_row - 1, math.max(0, start_row - 10), -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if line then
      -- Check for comment patterns
      if line:match("^%s*//") or line:match("^%s*#") or 
         line:match("^%s*%-%-") or line:match("^%s*/%*") then
        table.insert(doc_lines, 1, line)
      elseif line:match("^%s*%*/") then
        table.insert(doc_lines, 1, line)
        -- Continue to get the full block comment
      elseif #doc_lines > 0 and line:match("^%s*%*") then
        table.insert(doc_lines, 1, line)
      elseif line:match("^%s*$") and #doc_lines == 0 then
        -- Empty line, continue looking
      else
        -- Non-comment, non-empty line
        break
      end
    end
  end
  
  return #doc_lines > 0 and table.concat(doc_lines, "\n") or nil
end

-- Get the context for the current cursor position
function M.collect(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or 0
  local max_bytes = opts.max_bytes or 8000
  local max_lines = opts.max_lines or 200
  
  -- Validate buffer
  if not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify("Invalid buffer", vim.log.levels.ERROR)
    return nil
  end
  
  -- Get current node
  local node = M.get_node_at_cursor()
  if not node then 
    vim.notify("No Tree-sitter node found at cursor position", vim.log.levels.WARN)
    return nil 
  end
  
  -- Find enclosing function or class
  local context_node = M.find_parent_node(
    node,
    vim.list_extend(M.node_types.function_like, M.node_types.class_like)
  )
  
  if not context_node then
    context_node = node
  end
  
  -- Extract context
  local context = {
    language = parsers.get_buf_lang(bufnr),
    filepath = vim.fn.expand("%:~"),
    node_type = context_node:type(),
    range = {context_node:range()},
  }
  
  -- Get main content
  local content = M.get_node_text(context_node, bufnr)
  
  -- Limit by lines
  local lines = vim.split(content, "\n")
  if #lines > max_lines then
    lines = vim.list_slice(lines, 1, max_lines)
    content = table.concat(lines, "\n") .. "\n... (truncated)"
  end
  
  -- Limit by bytes
  if #content > max_bytes then
    content = content:sub(1, max_bytes) .. "\n... (truncated)"
  end
  
  context.content = content
  
  -- Extract imports
  context.imports = M.extract_imports(bufnr)
  
  -- Extract documentation
  context.documentation = M.extract_documentation(context_node, bufnr)
  
  -- Get parent context if requested
  if opts.include_parent then
    local parent = context_node:parent()
    if parent then
      local parent_node = M.find_parent_node(
        parent,
        vim.list_extend(M.node_types.function_like, M.node_types.class_like)
      )
      if parent_node then
        context.parent = {
          type = parent_node:type(),
          name = M.get_node_name(parent_node, bufnr),
          range = {parent_node:range()},
        }
      end
    end
  end
  
  -- Get sibling functions/methods if requested
  if opts.include_siblings and context_node:parent() then
    context.siblings = M.extract_siblings(context_node, bufnr)
  end
  
  return context
end

-- Extract sibling nodes (functions/methods at the same level)
function M.extract_siblings(node, bufnr)
  local siblings = {}
  local parent = node:parent()
  if not parent then return siblings end
  
  for child in parent:iter_children() do
    if child ~= node and vim.tbl_contains(M.node_types.function_like, child:type()) then
      table.insert(siblings, {
        type = child:type(),
        name = M.get_node_name(child, bufnr),
        range = {child:range()},
      })
    end
  end
  
  return siblings
end

-- Try to extract the name of a node (function name, class name, etc.)
function M.get_node_name(node, bufnr)
  if not node then return nil end
  
  -- Look for identifier child nodes
  for child in node:iter_children() do
    if child:type() == "identifier" or child:type() == "name" then
      return M.get_node_text(child, bufnr)
    end
  end
  
  -- Fallback: get first line and try to extract name
  local text = M.get_node_text(node, bufnr)
  local first_line = vim.split(text, "\n")[1]
  
  -- Common patterns
  local patterns = {
    "function%s+([%w_]+)",
    "def%s+([%w_]+)",
    "class%s+([%w_]+)",
    "struct%s+([%w_]+)",
    "interface%s+([%w_]+)",
  }
  
  for _, pattern in ipairs(patterns) do
    local name = first_line:match(pattern)
    if name then return name end
  end
  
  return nil
end

-- Update cursor context (called on cursor movement)
function M.update_cursor_context()
  local node = M.get_node_at_cursor()
  if not node then
    M._cursor_context = nil
    return
  end
  
  -- Find the smallest interesting node
  local context_node = node
  while context_node do
    local node_type = context_node:type()
    if vim.tbl_contains(M.node_types.function_like, node_type) or
       vim.tbl_contains(M.node_types.class_like, node_type) then
      break
    end
    context_node = context_node:parent()
  end
  
  if context_node then
    M._cursor_context = {
      node = context_node,
      type = context_node:type(),
      name = M.get_node_name(context_node),
      range = {context_node:range()},
    }
  else
    M._cursor_context = nil
  end
end

-- Get current cursor context
function M.get_cursor_context()
  return M._cursor_context
end

-- Build a context string for LLM consumption
function M.build_context_string(context)
  if not context then return "" end
  
  local parts = {}
  
  -- File information
  table.insert(parts, string.format("File: %s", context.filepath or "unknown"))
  table.insert(parts, string.format("Language: %s", context.language or "unknown"))
  
  -- Documentation
  if context.documentation then
    table.insert(parts, "\nDocumentation:")
    table.insert(parts, context.documentation)
  end
  
  -- Imports
  if context.imports and #context.imports > 0 then
    table.insert(parts, "\nImports:")
    for _, import in ipairs(context.imports) do
      table.insert(parts, import)
    end
  end
  
  -- Parent context
  if context.parent then
    table.insert(parts, string.format("\nParent: %s %s", 
      context.parent.type, context.parent.name or ""))
  end
  
  -- Main content
  table.insert(parts, "\nCode:")
  table.insert(parts, context.content)
  
  -- Siblings
  if context.siblings and #context.siblings > 0 then
    table.insert(parts, "\nSibling functions/methods:")
    for _, sibling in ipairs(context.siblings) do
      table.insert(parts, string.format("- %s %s", 
        sibling.type, sibling.name or "unnamed"))
    end
  end
  
  return table.concat(parts, "\n")
end

-- Build context for completion at cursor
function M.build_completion_context(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or 0
  
  -- Get cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  
  -- Get lines around cursor (before and current line up to cursor)
  local context_lines = math.min(row + 1, 50) -- Last 50 lines or less
  local start_line = math.max(0, row - context_lines + 1)
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, row + 1, false)
  
  -- Truncate the last line at cursor position
  if #lines > 0 then
    lines[#lines] = lines[#lines]:sub(1, col)
  end
  
  -- Get the current scope context
  local ctx = M.collect(opts)
  
  -- Build a focused context
  local parts = {}
  
  -- Add file and language info
  table.insert(parts, string.format("File: %s", vim.fn.expand("%:~")))
  table.insert(parts, string.format("Language: %s", vim.bo.filetype))
  
  -- Add imports if available
  if ctx and ctx.imports and #ctx.imports > 0 then
    table.insert(parts, "\nImports:")
    for _, import in ipairs(ctx.imports) do
      table.insert(parts, import)
    end
  end
  
  -- Add current function/class context if available
  if ctx and ctx.node_type then
    table.insert(parts, string.format("\nCurrent scope: %s %s", 
      ctx.node_type, 
      ctx.name or "anonymous"))
  end
  
  -- Add the code leading up to cursor
  table.insert(parts, "\nCode context (cursor at end):")
  table.insert(parts, table.concat(lines, "\n"))
  
  return table.concat(parts, "\n")
end

-- Clear cache
function M.clear_cache()
  M._cache = {}
end

return M 