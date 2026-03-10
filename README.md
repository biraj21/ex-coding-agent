# ExCode

An AI-powered coding assistant that runs in your terminal as an interactive REPL. Built with Elixir, ExCode provides intelligent code assistance using OpenAI-compatible APIs (including Cerebras).

## Features

- **Interactive REPL**: Chat with an AI assistant that understands your codebase
- **File Operations**: Read, write, and edit files with intelligent hashing for verification
- **Command Execution**: Run shell commands with user permission prompts for safety
- **Context Awareness**: Maintains conversation context across interactions
- **Tool Calling**: Leverages AI models with function calling capabilities
- **Rich Terminal UI**: Color-coded output with reasoning traces and tool call details

## Prerequisites

- **Elixir** ~> 1.19 ([Installation guide](https://elixir-lang.org/install.html))
- **OpenAI API Key** or compatible API (e.g., Cerebras)

## Setup

1. **Clone the repository**:

   ```bash
   git clone <repository-url>
   cd excode
   ```

2. **Install dependencies**:

   ```bash
   mix deps.get
   ```

3. **Configure environment variables**:
   Create a `.env` file in the project root with the following:

   ```env
   OPENAI_API_KEY=your_api_key_here
   OPENAI_BASE_URL=https://api.openai.com/v1  # or your compatible API endpoint
   OPENAI_MODEL=gpt-4o  # or your preferred model
   ```

   For Cerebras users:

   ```env
   OPENAI_API_KEY=your_cerebras_api_key
   OPENAI_BASE_URL=https://api.cerebras.ai/v1
   OPENAI_MODEL=llama3.1-70b
   ```

## Running ExCode

### Development Mode

```bash
make run
# or
mix run -e 'ExCode.main(System.argv())'
```

### Build Executable

```bash
make build
# or
mix escript.build
```

Then run the executable:

```bash
./excode
```

### Clean Build

```bash
make clean
```

## Usage

Once running, ExCode presents a simple REPL interface:

```
┌────────────────────────────┐
│           ExCode           │
└────────────────────────────┘

Base URL: https://api.openai.com/v1
Model: gpt-4o

> Your prompt here...
```

### REPL Commands

- **`/exit`** or **`/quit`** - Exit the REPL
- **`/ctx`** - Print the current conversation context

### Available Tools

ExCode can use the following tools (via AI function calling):

| Tool               | Description                                                     |
| ------------------ | --------------------------------------------------------------- |
| `read_file`        | Read and display file contents with line numbers and hashes     |
| `write_file`       | Write content to a file                                         |
| `run_bash_command` | Execute shell commands (requires user confirmation)             |
| `edit_file`        | Edit a specific range of lines in a file with hash verification |

### Safety Features

- **Command Confirmation**: All bash commands require explicit user approval before execution
- **Hash Verification**: File edits use line hashes to prevent accidental modifications
- **Sensitive File Protection**: Configured to avoid reading sensitive files (.env, keys, credentials)

## Example Session

```
> help me understand this project structure
[AI reads files, explores structure]
[AI provides analysis]

> create a new module for user authentication
[AI reads existing files to understand conventions]
[AI suggests implementation plan]
[AI writes the module]

> run tests
Can I run this command? [y/N] > y
[Test output displayed]
```

## Architecture

- **`lib/ex_code.ex`** - Entry point for the escript
- **`lib/ex_code/cli.ex`** - CLI handling and banner display
- **`lib/ex_code/repl.ex`** - REPL loop and input handling
- **`lib/ex_code/execute.ex`** - OpenAI API interaction and response handling
- **`lib/ex_code/tools.ex`** - Tool definitions and implementations
- **`lib/ex_code/context.ex`** - Conversation context management
- **`lib/ex_code/env.ex`** - Environment variable handling
- **`lib/ex_code/term_ui.ex`** - Terminal UI utilities
- **`lib/ex_code/system_prompt.ex`** - System prompt configuration

## License

MIT
