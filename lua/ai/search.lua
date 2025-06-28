-- Semantic Search Module
-- Tree-sitter powered code search and indexing

local M = {}
local Job = require("plenary.job")
local Path = require("plenary.path")
local context = require("ai.context")
local config = require("ai.config")
local parsers = require("nvim-treesitter.parsers")

-- Search index storage
M._index = {}
M._file_hashes = {}
M._indexing = false

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

-- Index a single file
function M.index_file(filepath)
  -- Skip if file doesn't exist or is too large
  if not M._should_index_file(filepath) then
    return
  end
  
  -- Read file content
  local ok, lines = pcall(vim.fn.readfile, filepath)
  if not ok or not lines then
    return
  end
  
  local content = table.concat(lines, "\n")
  
  -- Try to detect language from extension
  local ext = filepath:match("%.([^%.]+)$")
  local lang = nil
  
  -- Map common extensions to Tree-sitter language names
  local ext_to_lang = {
    lua = "lua",
    py = "python",
    js = "javascript",
    ts = "typescript",
    jsx = "javascript",
    tsx = "typescript",
    go = "go",
    rs = "rust",
    c = "c",
    cpp = "cpp",
    cc = "cpp",
    cxx = "cpp",
    h = "c",
    hpp = "cpp",
    java = "java",
    rb = "ruby",
    php = "php",
    cs = "c_sharp",
    swift = "swift",
    kt = "kotlin",
    scala = "scala",
    r = "r",
    m = "objc",
    mm = "objcpp",
    vim = "vim",
    sh = "bash",
    bash = "bash",
    zsh = "bash",
    fish = "fish",
    ps1 = "powershell",
    yaml = "yaml",
    yml = "yaml",
    json = "json",
    toml = "toml",
    ini = "ini",
    conf = "conf",
    xml = "xml",
    html = "html",
    css = "css",
    scss = "scss",
    sass = "sass",
    less = "less"
  }
  
  if ext then
    lang = ext_to_lang[ext:lower()]
  end
  
  -- Only parse if we have a known language and parser
  local symbols = {}
  if lang and pcall(require, "nvim-treesitter.parsers") then
    local parser_ok, parser = pcall(vim.treesitter.get_string_parser, content, lang)
    if parser_ok and parser then
      local tree_ok, tree = pcall(function() return parser:parse()[1] end)
      if tree_ok and tree then
        local root = tree:root()
        symbols = M._extract_symbols(root, content, lang)
      end
    end
  end
  
  -- Store in index
  M._index[filepath] = {
    content = content,
    symbols = symbols,
    indexed_at = os.time(),
  }
end

-- Index entire workspace
function M.index_workspace(callback)
  vim.schedule(function()
    vim.notify("AI Search: Indexing workspace...", vim.log.levels.INFO)
    
    M._index = {}
    M._file_cache = {}
    
    local config_settings = config.get()
    local exclude_patterns = config_settings.search.exclude_patterns
    
    -- Build find command with exclusions
    local find_cmd = { "find", ".", "-type", "f" }
    
    -- Add exclusions
    for _, pattern in ipairs(exclude_patterns) do
      -- Convert Lua pattern to find pattern
      if pattern:match("/$") then
        -- Directory pattern
        local dir = pattern:gsub("/$", ""):gsub("%%", "")
        table.insert(find_cmd, "-not")
        table.insert(find_cmd, "-path")
        table.insert(find_cmd, "*/" .. dir .. "/*")
      end
    end
    
    -- Add common code file extensions
    local extensions = {
      "lua", "py", "js", "ts", "jsx", "tsx", "go", "rs", "c", "cpp", "h",
      "java", "rb", "php", "cs", "swift", "kt", "scala", "r", "m", "mm",
      "vim", "sh", "bash", "zsh", "fish", "ps1", "yaml", "yml", "json",
      "toml", "ini", "conf", "xml", "html", "css", "scss", "sass", "less"
    }
    
    table.insert(find_cmd, "(")
    for i, ext in ipairs(extensions) do
      if i > 1 then
        table.insert(find_cmd, "-o")
      end
      table.insert(find_cmd, "-name")
      table.insert(find_cmd, "*." .. ext)
    end
    table.insert(find_cmd, ")")
    
    local files = {}
    local job = Job:new({
      command = find_cmd[1],
      args = vim.list_slice(find_cmd, 2),
      on_stdout = function(_, line)
        if line and line ~= "" then
          table.insert(files, line)
        end
      end,
      on_exit = function()
        vim.schedule(function()
          M.process_batch(files, 1, callback)
        end)
      end,
    })
    
    job:start()
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

-- Perform semantic search
function M.semantic_search(query, opts)
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

return M 