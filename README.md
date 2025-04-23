# Elixir SDK for OpenAI APIs

[![Hex.pm Version](https://img.shields.io/hexpm/v/ex_openai)](https://hex.pm/packages/ex_openai)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ex_openai)
[![Hex.pm Download Total](https://img.shields.io/hexpm/dt/ex_openai)](https://hex.pm/packages/ex_openai)

ExOpenAI is an (unofficial) Elixir SDK for interacting with the [OpenAI APIs](https://platform.openai.com/docs/api-reference/introduction). This SDK is fully auto-generated using [metaprogramming](https://elixirschool.com/en/lessons/advanced/metaprogramming/) and always reflects the latest state of the OpenAI API.

## Features

- Complete implementation of all OpenAI API endpoints
- Auto-generated with strict typing and documentation
- Elixir-style API with required arguments as function parameters and optional arguments as keyword lists
- Support for streaming responses with SSE
- Editor features: autocompletion, typechecking, and inline documentation
- Support with OpenAI-compatible APIs (like OpenRouter)

<img src="images/functiondocs.png" width="500" />

<img src="images/diagnostics.png" width="500" />

## Installation

Add **_:ex_openai_** as a dependency in your mix.exs file:

```elixir
def deps do
  [
    {:ex_openai, "~> 1.8.0"}
  ]
end
```

## Quick Start

### Configuration

```elixir
import Config

config :ex_openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  organization_key: System.get_env("OPENAI_ORGANIZATION_KEY"),
  # Optional settings
  base_url: System.get_env("OPENAI_API_URL"),
  http_options: [recv_timeout: 50_000],
  http_headers: [{"OpenAI-Beta", "assistants=v2"}]
```

### Basic Usage

```elixir
# List available models
{:ok, models} = ExOpenAI.Models.list_models()

# Create a completion
{:ok, completion} = ExOpenAI.Completions.create_completion("gpt-3.5-turbo-instruct", "The sky is")

# Chat completion
messages = [
  %ExOpenAI.Components.ChatCompletionRequestUserMessage{role: :user, content: "What is the capital of France?"}
]
{:ok, response} = ExOpenAI.Chat.create_chat_completion(messages, "gpt-4")

# Responses
{:ok, response} = ExOpenAI.Responses.create_response(
  "Tell me a joke about programming",
  "gpt-4o-mini"
)

# Continue the conversation
{:ok, follow_up} = ExOpenAI.Responses.create_response(
  "Explain why that joke is funny",
  "gpt-4o-mini",
  previous_response_id: response.id
)
```

More examples in [Examples](docs/examples.md)

## API Overview

ExOpenAI supports all OpenAI API endpoints, organized into logical modules:

- **Assistants** - Create and manage assistants
- **Audio** - Speech, transcription, and translation
- **Chat** - Chat completions API
- **Completions** - Text completion API
- **Embeddings** - Vector embeddings
- **Files** - File management
- **Images** - Image generation and editing
- **Models** - Model management
- **Responses** - Stateful conversation API
- **Threads** - Thread-based conversations
- **Vector Stores** - Vector database operations

For detailed documentation on each module, see the [API Documentation](https://hexdocs.pm/ex_openai).

## Advanced Usage

### Streaming Responses

```elixir
# Using a callback function
callback = fn
  :finish -> IO.puts "Done"
  {:data, data} -> IO.puts "Data: #{inspect(data)}"
  {:error, err} -> IO.puts "Error: #{inspect(err)}"
end

ExOpenAI.Completions.create_completion(
  "gpt-3.5-turbo-instruct",
  "Tell me a story",
  stream: true,
  stream_to: callback
)
```

For more advanced streaming options, see the [Streaming Guide](docs/streaming.md).

### File Uploads

```elixir
# Simple file upload
image_data = File.read!("path/to/image.png")
{:ok, result} = ExOpenAI.Images.create_image_variation(image_data)

# With filename information
audio_data = File.read!("path/to/audio.wav")
{:ok, transcript} = ExOpenAI.Audio.create_transcription({"audio.wav", audio_data}, "whisper-1")
```

## Documentation

- [Complete API Reference](https://hexdocs.pm/ex_openai)
- [Explanation on codegen](docs/codegen.md)
- [Streaming Guide](docs/streaming.md)
- [Configuration Options](docs/configuration.md)
- [Examples](docs/examples.md)

## Contributing

Contributions are welcome! If you find a bug or want to add a feature, please open an issue or submit a PR.

To update the SDK when OpenAI changes their API:

```bash
mix update_openai_docs
```

## Projects Using ExOpenAI

- [Elixir ChatGPT](https://github.com/dvcrn/elixir-chatgpt)
- [FixMyJP](https://fixmyjp.d.sh)
- [GPT Slack Bot](https://github.com/dvcrn/gpt-slack-bot)

_Add yours with a PR!_

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
