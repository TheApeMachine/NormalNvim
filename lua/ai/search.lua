-- Semantic Search Module
-- Tree-sitter powered code search and indexing

local M = {}
local Job = require("plenary.job")
local Path = require("plenary.path")
local context = require("ai.context")
local config = require("ai.config")
local parsers = require("nvim-treesitter.parsers")
local scan = require('plenary.scandir')

-- Search index storage
M._index = {}
M._file_hashes = {}
M._indexing = false

-- Configuration
M.config = {
  index_path = vim.fn.stdpath('cache') .. '/ai_search_index.json',
  exclude_dirs = {
    '.git', 'node_modules', '.venv', 'venv', '__pycache__', 
    'dist', 'build', 'target', '.idea', '.vscode'
  },
  include_extensions = {
    'lua', 'py', 'js', 'ts', 'jsx', 'tsx', 'go', 'rs', 
    'c', 'cpp', 'h', 'hpp', 'java', 'cs', 'rb', 'php'
  },
  max_file_size = 1024 * 1024, -- 1MB
}

-- Initialize search index
function M.initialize()
  if config.get().search.index_on_startup then
    vim.defer_fn(function()
      M.index_workspace()
    end, 1000)
  end
end

-- Check if file should be indexed
function M._should_index_file(filepath)
  -- Skip non-existent files
  if vim.fn.filereadable(filepath) ~= 1 then
    return false
  end
  
  -- Skip files based on patterns
  local config = require("ai.config").get()
  for _, pattern in ipairs(config.search.exclude_patterns) do
    if filepath:match(pattern) then
      return false
    end
  end
  
  -- Check file size
  local size = vim.fn.getfsize(filepath)
  if size > config.search.max_file_size then
    return false
  end
  
  -- Skip binary files by checking extension first
  local ext = filepath:match("%.([^%.]+)$")
  if ext then
    local binary_extensions = {
      "png", "jpg", "jpeg", "gif", "bmp", "ico", "webp",
      "pdf", "zip", "tar", "gz", "7z", "rar",
      "exe", "dll", "so", "dylib", "bin",
      "mp3", "mp4", "avi", "mov", "wmv",
      "ttf", "otf", "woff", "woff2",
      "db", "sqlite", "cache"
    }
    for _, bin_ext in ipairs(binary_extensions) do
      if ext:lower() == bin_ext then
        return false
      end
    end
  end
  
  -- For more complex filetype detection, we need to defer it
  -- Since we can't use vim.filetype.match in fast context
  return true
end

-- Extract symbols from AST
function M._extract_symbols(root, content, lang)
  local symbols = {}
  
  -- Language-specific queries
  local queries = {
    lua = [[
      (function_declaration name: (identifier) @name) @function
      (assignment_statement
        (variable_list
          name: (identifier) @name)
        (expression_list
          value: (function_definition))) @function
    ]],
    python = [[
      (function_definition name: (identifier) @name) @function
      (class_definition name: (identifier) @name) @class
    ]],
    javascript = [[
      (function_declaration name: (identifier) @name) @function
      (class_declaration name: (identifier) @name) @class
      (method_definition name: (property_identifier) @name) @method
    ]],
    typescript = [[
      (function_declaration name: (identifier) @name) @function
      (class_declaration name: (identifier) @name) @class
      (method_definition name: (property_identifier) @name) @method
      (interface_declaration name: (type_identifier) @name) @interface
    ]],
  }
  
  local query_string = queries[lang]
  if not query_string then
    -- Fallback: just extract function-like patterns
    return symbols
  end
  
  local ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
  if not ok then
    return symbols
  end
  
  for id, node in query:iter_captures(root, content) do
    local name = query.captures[id]
    local text = vim.treesitter.get_node_text(node, content)
    
    if text and text ~= "" then
      table.insert(symbols, {
        name = text,
        type = name,
        line = node:start() + 1,
      })
    end
  end
  
  return symbols
end

-- Check if a path should be excluded
local function should_exclude(path)
  for _, exclude in ipairs(M.config.exclude_dirs) do
    if path:match(exclude) then
      return true
    end
  end
  return false
end

-- Check if a file should be included
local function should_include(path)
  local ext = path:match("%.([^%.]+)$")
  if not ext then return false end
  
  for _, include_ext in ipairs(M.config.include_extensions) do
    if ext == include_ext then
      return true
    end
  end
  return false
end

-- Index a single file
function M.index_file(filepath)
  local path = Path:new(filepath)
  
  -- Check file size
  local stat = vim.loop.fs_stat(filepath)
  if not stat or stat.size > M.config.max_file_size then
    return nil
  end
  
  -- Read file content
  local ok, content = pcall(path.read, path)
  if not ok then
    return nil
  end
  
  -- Extract symbols using Tree-sitter if available
  local symbols = M._extract_symbols(filepath, content)
  
  return {
    path = filepath,
    content = content,
    symbols = symbols,
    size = stat.size,
    modified = stat.mtime.sec,
  }
end

-- Index the workspace
function M.index_workspace(callback)
  vim.schedule(function()
    vim.notify("AI Search: Indexing workspace...", vim.log.levels.INFO)
    
    M._index = {}
    M._file_cache = {}
    
    local workspace_root = vim.fn.getcwd()
    local files_indexed = 0
    
    -- Use plenary's scandir for cross-platform file scanning
    local files = scan.scan_dir(workspace_root, {
      hidden = false,
      depth = 10,
      add_dirs = false,
      respect_gitignore = true,
      on_insert = function(path)
        -- Check if we should process this file
        if should_exclude(path) then
          return false
        end
        if not should_include(path) then
          return false
        end
        
        -- Index the file
        local file_data = M.index_file(path)
        if file_data then
          M._index[path] = file_data
          files_indexed = files_indexed + 1
          
          -- Show progress every 100 files
          if files_indexed % 100 == 0 then
            vim.schedule(function()
              vim.notify(string.format("AI Search: Indexed %d files...", files_indexed), vim.log.levels.INFO)
            end)
          end
        end
        
        return true
      end,
    })
    
    -- Save index to cache
    M.save_index()
    
    vim.schedule(function()
      vim.notify(string.format("AI Search: Indexed %d files", files_indexed), vim.log.levels.INFO)
      M._last_indexed = os.time()
      if callback then callback() end
    end)
  end)
end

-- Process files in batches
function M.process_batch(files, start_idx, callback)
  local batch_size = 10
  local end_idx = math.min(start_idx + batch_size - 1, #files)
  
  if start_idx > #files then
    vim.schedule(function()
      local total = vim.tbl_count(M._index)
      vim.notify(string.format("AI Search: Indexed %d files", total), vim.log.levels.INFO)
      M._last_indexed = os.time()
      if callback then callback() end
    end)
    return
  end
  
  -- Process current batch
  for i = start_idx, end_idx do
    local file = files[i]
    if file and M._should_index_file(file) then
      M.index_file(file)
    end
  end
  
  -- Schedule next batch
  vim.defer_fn(function()
    M.process_batch(files, end_idx + 1, callback)
  end, 10) -- Small delay between batches
end

-- Update file in index
function M.update_file(filepath)
  filepath = vim.fn.fnamemodify(filepath, ":p")
  M.index_file(filepath)
end

-- Find definition of a symbol
function M.find_definition(symbol_name, opts)
  opts = opts or {}
  local results = M.semantic_search(symbol_name, opts)
  
  -- Return first result as the most likely definition
  return results[1]
end

-- Find references to a symbol
function M.find_references(symbol_name, opts)
  opts = opts or {}
  return M.semantic_search(symbol_name, opts)
end

-- Get index statistics
function M.get_stats()
  local total_files = vim.tbl_count(M._index)
  local total_symbols = 0
  
  for _, file_data in pairs(M._index) do
    if file_data.symbols then
      total_symbols = total_symbols + #file_data.symbols
    end
  end
  
  return {
    files = total_files,
    symbols = total_symbols,
    last_indexed = M._last_indexed,
  }
end

-- Semantic search with query understanding
M.semantic_search = function(query, opts)
  opts = opts or {}
  local max_results = opts.max_results or 10
  
  -- For now, use enhanced keyword search
  -- TODO: In the future, this will use embeddings
  local results = M.keyword_search(query, opts)
  
  -- If we have an LLM available and few results, we can enhance the search
  if #results < 5 and opts.use_llm then
    local llm = require('ai.llm')
    local context = require('ai.context')
    
    -- Ask LLM to expand the query
    local prompt = {
      {
        role = "system",
        content = "You are a code search assistant. Given a search query, suggest related keywords, function names, or concepts that might help find relevant code."
      },
      {
        role = "user", 
        content = string.format([[
Search query: "%s"

Suggest 3-5 alternative search terms or patterns that might help find relevant code.
Format as a JSON array of strings.
]], query)
      }
    }
    
    llm.request(prompt, { 
      max_tokens = 100,
      response_format = { type = "json_object" }
    }, function(response)
      if response then
        local ok, data = pcall(vim.json.decode, response)
        if ok and data.terms then
          -- Search with expanded terms
          for _, term in ipairs(data.terms) do
            local more_results = M.keyword_search(term, opts)
            for _, result in ipairs(more_results) do
              -- Avoid duplicates
              local duplicate = false
              for _, existing in ipairs(results) do
                if existing.file == result.file and existing.line == result.line then
                  duplicate = true
                  break
                end
              end
              if not duplicate then
                table.insert(results, result)
                if #results >= max_results then
                  break
                end
              end
            end
          end
        end
      end
    end)
  end
  
  return results
end

-- Keyword search (renamed from semantic_search)
M.keyword_search = function(query, opts)
  opts = opts or {}
  
  if vim.tbl_isempty(M._index) then
    return {}
  end
  
  -- Simple keyword-based search for now
  -- TODO: Integrate with LLM for true semantic search
  
  local results = {}
  local query_lower = query:lower()
  local keywords = vim.split(query_lower, "%s+")
  
  for filepath, file_data in pairs(M._index) do
    local content_lower = file_data.content:lower()
    local score = 0
    
    -- Check if all keywords appear in content
    local all_found = true
    for _, keyword in ipairs(keywords) do
      if content_lower:find(keyword, 1, true) then
        score = score + 1
      else
        all_found = false
      end
    end
    
    if all_found and score > 0 then
      -- Find best matching line
      local lines = vim.split(file_data.content, "\n")
      local best_line = 1
      local best_line_score = 0
      
      for i, line in ipairs(lines) do
        local line_lower = line:lower()
        local line_score = 0
        for _, keyword in ipairs(keywords) do
          if line_lower:find(keyword, 1, true) then
            line_score = line_score + 1
          end
        end
        if line_score > best_line_score then
          best_line = i
          best_line_score = line_score
        end
      end
      
      table.insert(results, {
        filepath = filepath,
        line = best_line,
        score = score,
        preview = lines[best_line] or "",
        symbols = file_data.symbols,
      })
    end
  end
  
  -- Sort by score
  table.sort(results, function(a, b)
    return a.score > b.score
  end)
  
  -- Limit results
  local max_results = opts.max_results or 20
  local limited_results = {}
  for i = 1, math.min(#results, max_results) do
    table.insert(limited_results, results[i])
  end
  
  return limited_results
end

-- Save index to disk
M.save_index = function()
  local cache_path = M.config.index_path
  local cache_dir = vim.fn.fnamemodify(cache_path, ':h')
  
  -- Ensure cache directory exists
  vim.fn.mkdir(cache_dir, 'p')
  
  -- Save index
  local ok, encoded = pcall(vim.json.encode, {
    version = 1,
    indexed_at = os.time(),
    workspace = vim.fn.getcwd(),
    index = M._index,
  })
  
  if ok then
    local file = io.open(cache_path, 'w')
    if file then
      file:write(encoded)
      file:close()
    end
  end
end

-- Load index from disk
M.load_index = function()
  local cache_path = M.config.index_path
  
  if vim.fn.filereadable(cache_path) == 0 then
    return false
  end
  
  local file = io.open(cache_path, 'r')
  if not file then
    return false
  end
  
  local content = file:read('*all')
  file:close()
  
  local ok, data = pcall(vim.json.decode, content)
  if ok and data and data.workspace == vim.fn.getcwd() then
    M._index = data.index or {}
    return true
  end
  
  return false
end

return M 