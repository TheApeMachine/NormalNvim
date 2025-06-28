# AI Assistant for Neovim

A Tree-sitter powered AI coding assistant that brings intelligent code completion, refactoring, and project understanding directly into Neovim.

## Features

### 🧠 Intelligent Context Extraction

- Uses Tree-sitter for accurate code parsing
- Understands function/class scope
- Extracts imports and dependencies
- Maintains cursor context for precise completions

### 💬 Multi-Provider LLM Support

- **OpenAI** (GPT-4, GPT-3.5) - with structured output support
- **Anthropic** (Claude)
- **Ollama** (Local models)
- Request queueing for rate limit handling
- Response caching for efficiency
- Streaming support for long responses (OpenAI only)

### ✏️ Smart Code Editing

- Syntax-aware code insertion
- Safe editing with validation
- Rollback on syntax errors
- Diff preview for changes
- Maintains proper indentation

### 🔧 Refactoring Tools

- Extract function from selection
- Rename symbols
- Simplify complex logic
- Add type annotations
- Organize imports

### 🔍 Code Search

- **Keyword search** across workspace
- Symbol extraction (functions, classes, etc.)
- Cross-platform file scanning
- Configurable file filters
- *Semantic search planned for future release*

### 📋 AI Planning System

- Multi-stage planning (understand → plan → review → execute)
- Interactive Q&A for clarification
- Project-aware with persistent memory
- Learns coding patterns and conventions
- Step-by-step execution with progress tracking

## Installation

### Prerequisites

- Neovim 0.9+ with Tree-sitter support
- Tree-sitter parsers for your languages
- API key for your chosen LLM provider

### Setup

1. Ensure the AI module is in your Neovim config:

```
~/.config/nvim/lua/ai/
```

2. Set up your API key:

```bash
export OPENAI_API_KEY="your-key-here"
# or
export ANTHROPIC_API_KEY="your-key-here"
```

3. Install Tree-sitter parsers:

```vim
:TSInstall python javascript typescript lua
```

## Commands

### General

- `:AIComplete [instruction]` - Complete code at cursor with optional instruction
- `:AIExplain` - Explain selected code
- `:AITest` - Test AI setup
- `:checkhealth ai` - Check AI assistant health

### Refactoring

- `:AIRefactor <instruction>` - Refactor with custom instruction
- `:AIExtractFunction` - Extract selection to function
- `:AIRename <new_name>` - Rename symbol
- `:AISimplifyLogic` - Simplify complex code
- `:AIAddTypes` - Add type annotations
- `:AIOrganizeImports` - Organize imports

### Search

- `:AISearch <query>` - Search codebase
- `:AIFindDefinition` - Find symbol definition
- `:AIFindReferences` - Find symbol references
- `:AIIndexWorkspace` - Index project files

### Planning

- `:AIPlan [task]` - Create implementation plan
- `:AIExecutePlan` - Execute current plan
- `:AIShowPlan` - View current plan
- `:AIAnalyzeProject` - Analyze project structure
- `:AILearnPatterns` - Learn coding patterns

### Inline Completion

- In insert mode: `<Tab>` to accept, `<Esc>` to dismiss

## Key Mappings

Default mappings with `<leader>a` prefix:

| Key           | Description          |
|---------------|----------------------|
| `<leader>ac`  | Complete with prompt |
| `<leader>ae`  | Explain code         |
| `<leader>arr` | Refactor (custom)    |
| `<leader>arf` | Extract function     |
| `<leader>ars` | Simplify logic       |
| `<leader>art` | Add types            |
| `<leader>aro` | Organize imports     |
| `<leader>arR` | Rename symbol        |
| `<leader>a/`  | Search semantically  |
| `<leader>ad`  | Find definition      |
| `<leader>aD`  | Find references      |
| `<leader>app` | Create plan          |
| `<leader>ape` | Execute plan         |
| `<leader>apP` | Show plan            |
| `<leader>apA` | Analyze project      |
| `<leader>apL` | Learn patterns       |
| `<leader>au`  | Undo last AI edit    |
| `<leader>aI`  | Index workspace      |

## Configuration

Configure in your `init.lua`:

```lua
require('ai').setup({
  -- Provider settings
  provider = 'openai',  -- 'openai', 'anthropic', or 'ollama'
  
  -- Context extraction
  context = {
    max_lines = 200,
    include_imports = true,
    include_diagnostics = true,
  },
  
  -- Performance
  performance = {
    cache_responses = true,
    cache_ttl_seconds = 3600,
    max_concurrent_requests = 3,
  },
  
  -- Search
  search = {
    exclude_dirs = {'.git', 'node_modules', 'dist'},
    include_extensions = {'lua', 'py', 'js', 'ts', 'go'},
    max_file_size = 1024 * 1024, -- 1MB
  },
})
```

## Architecture

The AI assistant is modular and extensible:

- **context.lua** - Tree-sitter based context extraction with caching
- **llm.lua** - Multi-provider LLM interface with queueing
- **edit.lua** - Safe code editing with validation
- **refactor.lua** - Refactoring operations
- **search.lua** - Code search with symbol extraction
- **planner.lua** - Project planning and execution
- **commands.lua** - User-facing commands
- **config.lua** - Configuration management

## Performance Features

- **Context caching** - Avoids re-parsing unchanged code
- **Response caching** - Caches LLM responses
- **Request queueing** - Handles rate limits gracefully
- **Streaming** - Supports streaming for long responses
- **Cross-platform** - Works on Windows, macOS, and Linux

## Troubleshooting

1. Run `:checkhealth ai` to diagnose issues
2. Check API keys are set correctly
3. Ensure Tree-sitter parsers are installed
4. Check `:messages` for error details

## Future Enhancements

- True semantic search with embeddings
- More refactoring operations
- Multi-file edits
- Test generation
- Documentation generation

## License

MIT
