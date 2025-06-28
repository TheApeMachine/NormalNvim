# Neovim AI Assistant

A Tree-sitter powered AI coding assistant for Neovim with intelligent context extraction, safe editing, multi-provider support, and **project-aware planning**.

## Features

- **Project-aware planning** - Multi-stage reasoning before code generation
- **Context-aware completions** - Uses Tree-sitter to understand code structure
- **Safe code editing** - Validates syntax before applying changes
- **Multi-provider support** - OpenAI, Anthropic, and Ollama
- **Advanced refactoring** - Extract functions, rename symbols, simplify logic
- **Semantic search** - Find code by meaning, not just text
- **Inline completions** - Ghost text suggestions like GitHub Copilot

## The Planning System

The AI Planning System addresses the common problem where AI assistants jump straight to code generation without understanding the broader project context. It uses a multi-stage approach:

1. **Understanding** - The AI analyzes your request and identifies what needs to be done
2. **Planning** - Creates a detailed step-by-step implementation plan
3. **Review** - A second AI pass reviews the plan for issues and risks
4. **Questions** - The AI can ask clarifying questions before proceeding
5. **Execution** - Only after approval does it generate code, following the plan

### Planning Commands

- **Create a plan** (`<leader>ap`): Start a planning session for a new feature
- **Show current plan** (`<leader>aP`): View the project's current plan and completed tasks
- **Analyze project** (`<leader>aA`): Have the AI analyze your project structure
- **Learn patterns** (`<leader>aL`): Update the AI's understanding of your coding patterns

### How Planning Works

When you use `<leader>ap` and describe what you want to implement, the AI will:

1. **Analyze the request** considering:
   - Current project structure
   - Existing patterns and conventions
   - Potential side effects
   - Breaking changes

2. **Create a plan** that includes:
   - Clear understanding of the task
   - Affected components and files
   - Step-by-step implementation
   - Potential issues and risks
   - Questions needing clarification

3. **Review the plan** for:
   - Completeness
   - Safety (won't break existing code)
   - Consistency with project patterns
   - Efficiency

4. **Show you the plan** with options to:
   - Execute it (press 'y')
   - Cancel (press 'n')
   - Edit the task description (press 'e')

The system maintains a `.ai-project-plan.json` file in your project root that tracks:

- Project architecture understanding
- Coding conventions
- Completed tasks
- Known issues

This persistent knowledge helps the AI make better decisions over time.

### 🧠 Intelligent Context Extraction

- Uses Tree-sitter to understand code structure
- Extracts relevant context including imports, documentation, and related code
- Supports multiple programming languages automatically
- Maintains a symbol graph for cross-reference analysis

### ✏️ Safe Code Editing

- Validates all edits using Tree-sitter before applying
- Automatic rollback on syntax errors
- Diff preview before applying changes
- Edit history with multi-step undo

### 🔄 Advanced Refactoring

- **Extract Function**: Extract selected code into a new function
- **Rename Symbol**: AI-powered symbol renaming across files
- **Simplify Logic**: Convert complex conditionals to guard clauses
- **Add Type Annotations**: Language-specific type additions
- **Organize Imports**: Smart import organization and cleanup

### 🔍 Semantic Code Search

- Project-wide code indexing using Tree-sitter
- Find definitions and references
- Symbol-based search with relevance scoring
- Incremental indexing on file changes

### 🤖 Multiple LLM Providers

- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude)
- Ollama (local models)
- Easy provider switching

## Usage Guide

### Getting Started

1. **Set up your API key** for your preferred provider:

   ```bash
   export OPENAI_API_KEY="your-key-here"
   # or
   export ANTHROPIC_API_KEY="your-key-here"
   ```

2. **Test your setup** with `<leader>aT` to verify everything is working.

### Code Completion

There are two ways to get AI completions:

1. **Interactive Completion** (`<leader>ac` in normal mode):
   - Prompts you for what you want the AI to do
   - Examples:
     - "Complete this function"
     - "Add error handling"
     - "Implement the TODO comment"
   - Shows a preview for larger completions
   - Validates syntax before inserting

2. **Inline Completion** (in insert mode):
   - Press `<leader>ai` to get a suggestion
   - Shows ghost text (gray) with the completion
   - Press `<Tab>` to accept or `<Esc>` to dismiss
   - Great for quick line completions

### Code Explanation

- **Explain code** (`<leader>ae`):
  - In normal mode: explains the function/class at cursor
  - In visual mode: explains the selected code
  - Opens a window with the explanation

### Refactoring

All refactoring operations validate syntax and show previews:

- **General refactor** (`<leader>ar`): Prompts for refactoring type
- **Rename symbol** (`<leader>aR`): Intelligently renames across scope
- **Extract function** (`<leader>af` in visual mode): Extracts selection to function
- **Simplify logic** (`<leader>as`): Simplifies complex conditionals
- **Add types** (`<leader>at`): Adds type annotations (TypeScript/Python)
- **Organize imports** (`<leader>ao`): Sorts and groups imports

### Code Search

- **Semantic search** (`<leader>a/`): Search by meaning
  - Example: "function that handles user authentication"
- **Find definition** (`<leader>ad`): Jump to symbol definition
- **Find references** (`<leader>aD`): Find all usages

### Safety Features

1. **Syntax Validation**: All edits are checked with Tree-sitter before applying
2. **Preview Mode**: Large changes show a diff preview first
3. **Undo Support**: `<leader>au` to undo the last AI edit
4. **Error Recovery**: Failed edits are shown in a window for manual review

### Tips

- The AI understands your current context - it knows what function you're in, what imports are available, etc.
- Be specific in your prompts for better results
- Use inline completion for quick suggestions while typing
- Use interactive completion for larger changes or when you need specific behavior

## Installation

The module is already integrated into your Neovim configuration. Make sure you have:

1. Set your API key as an environment variable:

   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   # or
   export ANTHROPIC_API_KEY="your-api-key-here"
   ```

2. Installed Tree-sitter parsers for your languages:

   ```vim
   :TSInstall python javascript typescript rust go
   ```

## Usage

### Commands

#### Completion & Explanation

- `:AIComplete [instruction]` - Complete code at cursor with optional instruction
- `:AIExplain [question]` - Explain selected code or current context

#### Refactoring

- `:AIRefactor <instruction>` - Refactor with custom instruction
- `:AIRename <new_name>` - Rename symbol under cursor
- `:AIExtractFunction` - Extract visual selection into function
- `:AISimplifyLogic` - Simplify conditional logic
- `:AIAddTypes` - Add type annotations
- `:AIOrganizeImports` - Organize and clean imports

#### Search & Navigation

- `:AISearch <query>` - Search codebase
- `:AIFindDefinition [symbol]` - Find symbol definition
- `:AIFindReferences [symbol]` - Find symbol references

#### Configuration

- `:AISetProvider <provider>` - Switch LLM provider
- `:AISetModel <model>` - Change model for current provider
- `:AIIndexWorkspace` - Index entire workspace
- `:AIIndexStats` - Show indexing statistics

#### Utilities

- `:AIUndo [steps]` - Undo AI edits
- `:AIClearCache` - Clear all caches
- `:AIDebugContext` - Debug context extraction

### Key Mappings

All mappings use the `<leader>a` prefix:

| Key | Description | Mode |
|-----|-------------|------|
| `<leader>ac` | AI Complete | Normal |
| `<leader>ae` | AI Explain | Normal, Visual |
| `<leader>ar` | AI Refactor | Normal, Visual |
| `<leader>aR` | AI Rename | Normal |
| `<leader>af` | Extract Function | Visual |
| `<leader>as` | Simplify Logic | Normal |
| `<leader>at` | Add Types | Normal |
| `<leader>ai` | Organize Imports | Normal |
| `<leader>a/` | AI Search | Normal |
| `<leader>ad` | Find Definition | Normal |
| `<leader>aD` | Find References | Normal |
| `<leader>au` | AI Undo | Normal |
| `<leader>aI` | Index Workspace | Normal |

## Configuration

The module can be configured through the setup function:

```lua
require("ai").setup({
  -- Provider settings
  provider = "openai", -- "openai", "anthropic", "ollama"
  
  -- API configurations
  api = {
    openai = {
      api_key = vim.env.OPENAI_API_KEY,
      model = "gpt-4o-mini",
      temperature = 0.3,
      max_tokens = 4096,
    },
  },
  
  -- Context extraction
  context = {
    max_bytes = 8000,
    max_lines = 200,
    include_imports = true,
    include_siblings = true,
    search_radius = 2,
  },
  
  -- Editing behavior
  editing = {
    validate_syntax = true,
    auto_format = true,
    safe_mode = true,
    diff_preview = true,
  },
  
  -- Search indexing
  search = {
    enable_index = true,
    index_on_startup = false,
    max_file_size = 100000,
    exclude_patterns = {
      "%.git/",
      "node_modules/",
      "%.min%.js$",
    },
  },
})
```

## How It Works

### Context-Aware Prompting

The AI assistant uses Tree-sitter to extract the most relevant context for each request:

1. Identifies the current function/class scope
2. Extracts imports and dependencies
3. Includes documentation and comments
4. Builds a minimal but complete context

### Safe Editing with Parse Gates

Every edit goes through validation:

1. Apply the edit to a buffer
2. Parse with Tree-sitter
3. Check for syntax errors
4. Rollback if invalid, commit if valid

### Semantic Search Index

The search index maintains:

- Function and class definitions
- Import statements
- Documentation blocks
- Symbol relationships

## Examples

### Extract a Function

1. Select code in visual mode
2. Press `<leader>af`
3. AI extracts the code into a well-named function with proper parameters

### Simplify Complex Logic

```python
# Before
def process(data):
    if data is not None:
        if len(data) > 0:
            if validate(data):
                return transform(data)
            else:
                return None
        else:
            return None
    else:
        return None

# After :AISimplifyLogic
def process(data):
    if data is None:
        return None
    if len(data) == 0:
        return None
    if not validate(data):
        return None
    return transform(data)
```

### Smart Rename

```vim
:AIRename calculateTotalPrice
```

Renames the symbol under cursor and all its references throughout the codebase.

## Performance Tips

1. **Indexing**: For large projects, index during off-hours:

   ```vim
   :AIIndexWorkspace
   ```

2. **Context Size**: Adjust context limits for better performance:

   ```lua
   context = {
     max_bytes = 4000,  -- Smaller context
     max_lines = 100,
   }
   ```

3. **Cache Usage**: The module caches LLM responses. Clear if needed:

   ```vim
   :AIClearCache
   ```

## Troubleshooting

### No Context Found

- Ensure Tree-sitter parser is installed for your language
- Check if cursor is inside a function/class

### Syntax Validation Fails

- The AI might have produced invalid code
- Check `:AIDebugContext` to see what context was sent
- Try with a more specific instruction

### Slow Performance

- Reduce context size in configuration
- Disable auto-indexing if not needed
- Use a faster model (e.g., gpt-3.5-turbo)

## Architecture

```text
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ Tree-sitter │────▶│Context Engine│────▶│ LLM Provider│
└─────────────┘     └──────────────┘     └─────────────┘
       │                    │                     │
       ▼                    ▼                     ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ Parse Tree  │     │Symbol Graph  │     │ AI Response │
└─────────────┘     └──────────────┘     └─────────────┘
       │                    │                     │
       └────────────────────┴─────────────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │ Safe Editor  │
                    └──────────────┘
```

## Contributing

The AI assistant is modular and extensible:

- **Add Providers**: Implement new providers in `lua/ai/llm.lua`
- **Add Refactorings**: Add operations in `lua/ai/refactor.lua`
- **Improve Context**: Enhance extraction in `lua/ai/context.lua`
- **Add Languages**: Update node types in `lua/ai/context.lua`

## License

This module is part of your Neovim configuration and follows the same license.
