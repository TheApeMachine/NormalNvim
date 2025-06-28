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

- **Semantic search with embeddings** (OpenAI)
- **Keyword search** (all providers)
- Symbol extraction (functions, classes, etc.)
- Cross-platform file scanning
- Configurable file filters
- Similarity-based code discovery

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
    use_embeddings = true,
    embedding_model = "text-embedding-3-small", -- or "text-embedding-3-large"
    embedding_dimensions = 512, -- Lower = faster/cheaper, Higher = better quality
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

## Semantic Search with Embeddings

The AI assistant supports true semantic search using OpenAI's latest embedding models. This allows you to search for code by meaning, not just keywords.

### Embedding Models

We use OpenAI's newest embedding models (released January 2024):

- **text-embedding-3-small** (default): 
  - 5x cheaper than ada-002 ($0.02 per 1M tokens)
  - Higher quality embeddings
  - Configurable dimensions (256-1536)
  - Default: 512 dimensions for balance of quality/speed

- **text-embedding-3-large**: 
  - Best quality available
  - Configurable dimensions (256-3072)
  - Use for critical search accuracy

### Configuration

```lua
search = {
  use_embeddings = true,
  embedding_model = "text-embedding-3-small", -- or "text-embedding-3-large"
  embedding_dimensions = 512, -- Lower = faster/cheaper, Higher = better quality
}
```

### How it Works

1. **Code Chunking**: Files are intelligently split into semantic chunks (functions, classes) using Tree-sitter
2. **Embedding Generation**: Each chunk is converted to a vector embedding using the configured model
3. **Similarity Search**: Your query is embedded and compared against all code chunks using cosine similarity
4. **Smart Results**: Results are ranked by semantic similarity, with keyword search as fallback

### Enabling Embeddings

```vim
" Enable embeddings-based search
:AIEnableEmbeddings

" Re-index workspace with embeddings (required after enabling)
:AIIndexWorkspace

" Search semantically
:AISearch how to handle user authentication
```

### Performance Benefits

The new models offer significant improvements:

- **5x cost reduction**: text-embedding-3-small costs $0.02 per 1M tokens (vs $0.10 for ada-002)
- **Better accuracy**: Improved embedding quality for code understanding
- **Flexible dimensions**: Reduce dimensions to save storage and improve speed
- **Larger context**: Supports up to 8,191 tokens per embedding

### Dimension Trade-offs

| Dimensions | Quality | Speed | Storage | Use Case |
|------------|---------|-------|---------|----------|
| 256 | Good | Fastest | Smallest | Quick searches, large codebases |
| 512 | Better | Fast | Small | Default, balanced performance |
| 1024 | Best | Moderate | Moderate | High accuracy needed |
| 1536/3072 | Maximum | Slower | Larger | Critical search accuracy |

### Performance Considerations

- Initial indexing with embeddings takes longer (processes files in batches)
- Embeddings are cached locally in `~/.cache/nvim/ai_embeddings.json`
- Each file generates multiple embeddings (one per function/class)
- API costs are very low: ~$0.00002 per file with the new models

### Fallback Behavior

- If OpenAI is not available, falls back to n-gram based embeddings (less accurate but works offline)
- If no embeddings exist, falls back to keyword search
- Keyword results supplement semantic results when needed

## Interactive Chat

The AI assistant now includes an interactive chat panel for conversational coding assistance:

### Opening the Chat

Use `:AIChat` or map it to a key:

```lua
vim.keymap.set('n', '<leader>ac', ':AIChat<CR>', { desc = 'AI Chat' })
```

### Chat Features

The chat window provides a persistent conversation with the AI:

- **Context-aware**: Include code context using special commands
- **Streaming responses**: See the AI's response as it's generated
- **Code blocks**: Apply or copy code directly from the chat
- **Persistent history**: Continue conversations across sessions

### Context Commands

When typing a message, use these special commands to include context:

- `@buffer` - Include the entire current buffer
- `@selection` - Include the last visual selection
- `@file:path/to/file.lua` - Include a specific file

Example:
```
Can you explain this function? @buffer
```

### Chat Window Commands

While in the chat window:

- `i`, `o` - Start typing a new message
- `a` - Apply code block at cursor to the previous buffer
- `y` - Copy code block at cursor to clipboard
- `d` - Delete chat history
- `q`, `<Esc>` - Close chat window

### Example Workflow

1. Open a file you're working on
2. Run `:AIChat` to open the chat panel
3. Type: "How can I optimize this function? @buffer"
4. Review the AI's suggestions
5. Place cursor on a code block and press `a` to apply it
6. Continue the conversation with follow-up questions

The chat maintains context across messages, making it ideal for:
- Debugging sessions
- Code reviews
- Learning new concepts
- Iterative development

## Multi-File Operations

The AI assistant now supports complex refactorings across multiple files with transaction support:

### Symbol Renaming

Rename symbols (functions, variables, classes) across your entire codebase:

```vim
:AIRenameSymbol [new_name]
```

- Finds all occurrences using ripgrep
- Shows preview of all changes before applying
- Supports rollback if something goes wrong

### Module Extraction

Extract related functionality into a new module:

```vim
:AIExtractModule [module_name]
```

The AI will:
1. Analyze which code should be moved
2. Create the new module file
3. Update imports in affected files
4. Preview all changes before applying

### Transaction System

All multi-file operations use a transaction system:
- Preview changes before applying
- Automatic backup of modified files
- Rollback capability if errors occur
- Press `a` to apply, `q` to cancel in preview

## AI-Powered Testing

Generate and maintain comprehensive test suites automatically:

### Generate Tests

```vim
:AIGenerateTests [framework]
```

- Automatically detects test framework (Jest, pytest, etc.)
- Generates tests covering:
  - Happy paths
  - Edge cases
  - Error conditions
  - Type checking
- Places tests in appropriate directory

### Update Tests

```vim
:AIUpdateTests
```

Updates existing tests when implementation changes:
- Matches API changes
- Adds tests for new functionality
- Removes obsolete tests
- Preserves valid existing tests

### Analyze Test Failures

```vim
:AIAnalyzeTestFailures [output]
```

- Parses test output or quickfix list
- Identifies root causes
- Suggests specific fixes
- Distinguishes between test bugs and implementation bugs

## Debugging Assistant

Advanced debugging support with AI-powered analysis:

### Error Analysis

```vim
:AIDebugError [error_text]
```

Analyzes stack traces and errors:
- Parses stack traces for any language
- Extracts relevant code context
- Provides root cause analysis
- Suggests specific fixes
- Creates navigable report with quick jumps to error locations

### Apply Fixes

```vim
:AIApplyFix
```

Apply suggested fixes from error analysis with preview.

### Interactive Debug Session

```vim
:AIDebugSession
```

Start an AI-assisted debugging REPL:
- Set breakpoints with `:break <line>`
- Watch expressions with `:watch <expr>`
- Evaluate code with `:eval <expr>`
- Get AI guidance at each step

### Performance Analysis

```vim
:AIAnalyzePerformance [profile_data]
```

Analyze performance profiles:
- Identifies bottlenecks
- Explains root causes
- Suggests optimizations
- Discusses trade-offs

## Code Quality Tools

### Generate Commit Messages

```vim
:AICommitMessage
```

Generates conventional commit messages from staged changes:
- Follows Conventional Commits spec
- Analyzes git diff
- Suggests appropriate type and scope
- Can be used directly in git commit buffer

### Code Review

```vim
:AIReviewCode
```

Get AI code review for current function/file:
- Checks for bugs and logic errors
- Identifies performance issues
- Spots security vulnerabilities
- Suggests improvements
- Follows language best practices

## Production-Ready Features

This plugin is designed for serious, production codebases:

1. **Transaction Support**: All multi-file operations can be previewed and rolled back
2. **Framework Detection**: Automatically detects and adapts to your project's tools
3. **Error Recovery**: Graceful handling of failures with automatic rollback
4. **Context Awareness**: Understands your project structure and patterns
5. **Language Agnostic**: Works with any language supported by Tree-sitter

## Example Workflows

### Test-Driven Development
1. Write implementation
2. Run `:AIGenerateTests` to create comprehensive tests
3. Make changes to implementation
4. Run `:AIUpdateTests` to keep tests in sync

### Debugging Production Issues
1. Copy error/stack trace
2. Run `:AIDebugError` to analyze
3. Navigate to error locations with number keys
4. Review suggested fixes
5. Run `:AIApplyFix` to apply changes

### Large-Scale Refactoring
1. Run `:AIRenameSymbol` to rename across codebase
2. Use `:AIExtractModule` to reorganize code
3. Preview all changes before applying
4. Rollback if needed

### Code Quality Workflow
1. Make changes
2. Run `:AIReviewCode` for AI review
3. Stage changes
4. Run `:AICommitMessage` for commit message
5. Use generated message with confidence
