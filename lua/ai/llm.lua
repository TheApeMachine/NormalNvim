-- LLM Integration Module
-- Supports multiple LLM providers with async operations

local M = {}
local Job = require("plenary.job")
local config = require("ai.config")

-- Response cache
M._cache = {}
M._active_requests = {}

-- Provider implementations
M.providers = {}

-- OpenAI provider
M.providers.openai = {
  prepare_request = function(prompt, opts)
    local api_config = config.get().api.openai
    opts = vim.tbl_extend("force", {
      model = api_config.model,
      temperature = api_config.temperature,
      max_tokens = api_config.max_tokens,
    }, opts or {})
    
    local messages = type(prompt) == "string" 
      and {{ role = "user", content = prompt }}
      or prompt
    
    local body = {
      model = opts.model,
      messages = messages,
      temperature = opts.temperature,
      max_tokens = opts.max_tokens,
      stream = false,
    }
    
    -- Add response_format for structured outputs
    if opts.response_format then
      -- Handle both simple json_object and json_schema formats
      if opts.response_format.type == "json_schema" then
        body.response_format = {
          type = "json_schema",
          json_schema = opts.response_format.json_schema
        }
      else
        body.response_format = opts.response_format
      end
    end
    
    return {
      url = api_config.endpoint,
      headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. api_config.api_key,
      },
      body = vim.json.encode(body),
    }
  end,
  
  parse_response = function(response_text)
    local ok, data = pcall(vim.json.decode, response_text)
    if not ok then
      return nil, "Failed to parse response: " .. response_text
    end
    
    if data.error then
      return nil, data.error.message or "Unknown error"
    end
    
    if data.choices and data.choices[1] and data.choices[1].message then
      return data.choices[1].message.content, nil
    end
    
    return nil, "Invalid response format"
  end,
}

-- Anthropic provider
M.providers.anthropic = {
  prepare_request = function(prompt, opts)
    local api_config = config.get().api.anthropic
    opts = vim.tbl_extend("force", {
      model = api_config.model,
      temperature = api_config.temperature,
      max_tokens = api_config.max_tokens,
    }, opts or {})
    
    local messages = type(prompt) == "string"
      and {{ role = "user", content = prompt }}
      or prompt
    
    -- Convert from OpenAI format if needed
    local anthropic_messages = {}
    for _, msg in ipairs(messages) do
      if msg.role == "system" then
        -- Anthropic uses system as a separate field
        opts.system = msg.content
      else
        table.insert(anthropic_messages, {
          role = msg.role,
          content = msg.content,
        })
      end
    end
    
    local body = {
      model = opts.model,
      messages = anthropic_messages,
      temperature = opts.temperature,
      max_tokens = opts.max_tokens,
    }
    
    if opts.system then
      body.system = opts.system
    end
    
    return {
      url = api_config.endpoint,
      headers = {
        ["Content-Type"] = "application/json",
        ["x-api-key"] = api_config.api_key,
        ["anthropic-version"] = "2023-06-01",
      },
      body = vim.json.encode(body),
    }
  end,
  
  parse_response = function(response_text)
    local ok, data = pcall(vim.json.decode, response_text)
    if not ok then
      return nil, "Failed to parse response: " .. response_text
    end
    
    if data.error then
      return nil, data.error.message or "Unknown error"
    end
    
    if data.content and data.content[1] and data.content[1].text then
      return data.content[1].text, nil
    end
    
    return nil, "Invalid response format"
  end,
}

-- Ollama provider
M.providers.ollama = {
  prepare_request = function(prompt, opts)
    local api_config = config.get().api.ollama
    opts = vim.tbl_extend("force", {
      model = api_config.model,
      temperature = api_config.temperature,
    }, opts or {})
    
    local prompt_text = type(prompt) == "string" 
      and prompt
      or M._messages_to_text(prompt)
    
    return {
      url = api_config.endpoint,
      headers = {
        ["Content-Type"] = "application/json",
      },
      body = vim.json.encode({
        model = opts.model,
        prompt = prompt_text,
        temperature = opts.temperature,
        stream = false,
      }),
    }
  end,
  
  parse_response = function(response_text)
    local ok, data = pcall(vim.json.decode, response_text)
    if not ok then
      return nil, "Failed to parse response: " .. response_text
    end
    
    if data.error then
      return nil, data.error or "Unknown error"
    end
    
    if data.response then
      return data.response, nil
    end
    
    return nil, "Invalid response format"
  end,
}

-- Convert messages array to text for providers that don't support chat format
function M._messages_to_text(messages)
  local parts = {}
  for _, msg in ipairs(messages) do
    if msg.role == "system" then
      table.insert(parts, "System: " .. msg.content)
    elseif msg.role == "user" then
      table.insert(parts, "User: " .. msg.content)
    elseif msg.role == "assistant" then
      table.insert(parts, "Assistant: " .. msg.content)
    end
  end
  return table.concat(parts, "\n\n")
end

-- Helper to generate cache key
function M._generate_cache_key(provider_name, prompt, opts)
  -- Use a simple string concatenation for cache key to avoid vim.fn calls in fast context
  local key_string = provider_name .. "|" .. vim.inspect(prompt) .. "|" .. vim.inspect(opts)
  -- Simple hash function
  local hash = 0
  for i = 1, #key_string do
    hash = (hash * 31 + string.byte(key_string, i)) % 2147483647
  end
  return tostring(hash)
end

-- Make an async request to the LLM
function M.request(prompt, opts, callback)
  opts = opts or {}
  local provider_name = opts.provider or config.get().provider
  local provider = M.providers[provider_name]
  
  if not provider then
    callback(nil, "Unknown provider: " .. provider_name)
    return
  end
  
  -- Check cache if enabled
  local cache_key = nil
  if config.get().performance.cache_responses then
    cache_key = M._generate_cache_key(provider_name, prompt, opts)
    local cached = M._cache[cache_key]
    if cached and (os.time() - cached.time) < config.get().performance.cache_ttl_seconds then
      callback(cached.response, nil)
      return
    end
  end
  
  -- Prepare request
  local request_data = provider.prepare_request(prompt, opts)
  
  -- Check concurrent requests limit
  if #M._active_requests >= config.get().performance.max_concurrent_requests then
    callback(nil, "Too many concurrent requests")
    return
  end
  
  -- Build curl command
  local curl_args = {
    "-sS",
    request_data.url,
    "-X", "POST",
  }
  
  for header, value in pairs(request_data.headers) do
    table.insert(curl_args, "-H")
    table.insert(curl_args, header .. ": " .. value)
  end
  
  table.insert(curl_args, "-d")
  table.insert(curl_args, request_data.body)
  
  -- Create job
  local job = Job:new({
    command = "curl",
    args = curl_args,
    on_exit = function(j, return_val)
      -- Remove from active requests
      for i, req in ipairs(M._active_requests) do
        if req == job then
          table.remove(M._active_requests, i)
          break
        end
      end
      
      if return_val ~= 0 then
        vim.schedule(function()
          callback(nil, "Request failed with code: " .. return_val)
        end)
        return
      end
      
      local response = table.concat(j:result(), "\n")
      local result, err = provider.parse_response(response)
      
      if result and cache_key then
        -- Cache successful response
        M._cache[cache_key] = {
          response = result,
          time = os.time(),
        }
      end
      
      vim.schedule(function()
        callback(result, err)
      end)
    end,
  })
  
  -- Track active request
  table.insert(M._active_requests, job)
  
  -- Start job
  job:start()
end

-- Synchronous request wrapper
function M.request_sync(prompt, opts)
  local result, error = nil, nil
  local done = false
  
  M.request(prompt, opts, function(res, err)
    result = res
    error = err
    done = true
  end)
  
  -- Wait for completion (with timeout)
  local timeout = 30000 -- 30 seconds
  local start = vim.loop.now()
  while not done and (vim.loop.now() - start) < timeout do
    vim.wait(10)
  end
  
  if not done then
    return nil, "Request timeout"
  end
  
  return result, error
end

-- Build a prompt for code completion
function M.build_completion_prompt(context, instruction)
  local system_prompt = [[You are an expert programmer providing code completions. 

CRITICAL RULES:
1. Generate ONLY the code to be inserted at the cursor position
2. Do NOT include code that already exists in the context
3. Ensure proper indentation matching the surrounding code
4. Complete partial statements or add new code as requested
5. The code must be syntactically valid when inserted at the cursor
6. Pay attention to:
   - Open parentheses, brackets, or braces that need closing
   - Current indentation level
   - Whether you're inside a function, class, or other scope
   - Language-specific syntax requirements

Follow the existing code style and conventions.]]
  
  local user_prompt = string.format([[
Context:
%s

Instruction: %s

Generate only the code to insert at the cursor position. The cursor is at the end of the provided context.
]], context, instruction or "Complete the code at the cursor position")
  
  return {
    { role = "system", content = system_prompt },
    { role = "user", content = user_prompt },
  }
end

-- Build a prompt for refactoring
function M.build_refactor_prompt(code, instruction)
  local system_prompt = [[You are an expert programmer. Refactor the provided code according to the instructions. 
Maintain the same functionality while improving code quality. Output only the refactored code.]]
  
  return {
    { role = "system", content = system_prompt },
    { role = "user", content = code .. "\n\nRefactoring instruction: " .. instruction },
  }
end

-- Build a prompt for explanation
function M.build_explanation_prompt(code, question)
  local system_prompt = [[You are an expert programmer and teacher. Explain the code clearly and concisely.
Use examples when helpful. Format your response in markdown.]]
  
  local user_prompt = code
  if question then
    user_prompt = user_prompt .. "\n\nQuestion: " .. question
  end
  
  return {
    { role = "system", content = system_prompt },
    { role = "user", content = user_prompt },
  }
end

-- Clear response cache
function M.clear_cache()
  M._cache = {}
end

-- Cancel all active requests
function M.cancel_all()
  for _, job in ipairs(M._active_requests) do
    job:shutdown()
  end
  M._active_requests = {}
end

return M 