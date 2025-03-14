# Elixir SDK for OpenAI APIs

[![Hex.pm Version](https://img.shields.io/hexpm/v/ex_openai)](https://hex.pm/packages/ex_openai)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ex_openai)
[![Hex.pm Download Total](https://img.shields.io/hexpm/dt/ex_openai)](https://hex.pm/packages/ex_openai)

ExOpenAI is an (unofficial) Elixir SDK for interacting with the [OpenAI APIs](https://platform.openai.com/docs/api-reference/introduction)

This SDK is fully auto-generated using [metaprogramming](https://elixirschool.com/en/lessons/advanced/metaprogramming/) and should always reflect the latest state of the OpenAI API.

**Note:** Due to the nature of auto-generating something, you may encounter stuff that isn't working yet. Make sure to report if you notice anything acting up.

- [Elixir SDK for OpenAI APIs](#elixir-sdk-for-openai-apis)
	- [Features](#features)
	- [Installation](#installation)
	- [Supported endpoints (basically everything)](#supported-endpoints-basically-everything)
		- [Assistants](#assistants)
		- [Audio](#audio)
		- [Batches](#batches)
		- [Chat Completions](#chat-completions)
		- [Completions](#completions)
		- [Embeddings](#embeddings)
		- [Files](#files)
		- [Fine-tuning](#fine-tuning)
		- [Images](#images)
		- [Models](#models)
		- [Moderations](#moderations)
		- [Organization](#organization)
		- [Realtime](#realtime)
		- [Responses](#responses)
			- [Using the Responses API](#using-the-responses-api)
		- [Threads](#threads)
		- [Uploads](#uploads)
		- [Vector Stores](#vector-stores)
		- [Editor features: Autocomplete, specs, docs](#editor-features-autocomplete-specs-docs)
			- [Autocompletion/type-hinting through LSP / ElixirSense](#autocompletiontype-hinting-through-lsp--elixirsense)
			- [Typechecking and diagnostics through strict @spec definitions](#typechecking-and-diagnostics-through-strict-spec-definitions)
			- [Inline docs and signatures thanks to @spec and @doc](#inline-docs-and-signatures-thanks-to-spec-and-doc)
	- [To Do's / What's not working yet](#to-dos--whats-not-working-yet)
	- [Configuration](#configuration)
	- [Usage](#usage)
		- [Using ChatGPT APIs](#using-chatgpt-apis)
		- [Using Assistant APIs](#using-assistant-apis)
		- [Usage of endpoints that require files to upload](#usage-of-endpoints-that-require-files-to-upload)
			- [File endpoints that require filename information (Audio transcription)](#file-endpoints-that-require-filename-information-audio-transcription)
		- [Usage of Audio related](#usage-of-audio-related)
		- [Streaming data](#streaming-data)
			- [Streaming with a callback function](#streaming-with-a-callback-function)
			- [Streaming with a separate process](#streaming-with-a-separate-process)
			- [Caveats](#caveats)
	- [How to update once OpenAI changes something?](#how-to-update-once-openai-changes-something)
	- [Some stuff built using this SDK (add yours with a PR!)](#some-stuff-built-using-this-sdk-add-yours-with-a-pr)
	- [How auto-generation works / how can I extend this?](#how-auto-generation-works--how-can-i-extend-this)
	- [License](#license)
	- [Attribution](#attribution)

## Features

- Up-to-date and complete thanks to metaprogramming and code-generation
- Implements _everything_ the OpenAI has to offer
- Strictly follows the official OpenAI APIs for argument/function naming
- Handling of required arguments as function parameters and optional arguments as Keyword list in true Elixir-fashion
- Auto-generated embedded function documentation
- Auto-generated @spec definitions for dialyzer, for strict parameter typing
- Support for streaming responses with SSE

## Installation

Add **_:ex_openai_** as a dependency in your mix.exs file.

```elixir
def deps do
  [
    {:ex_openai, "~> 1.7"}
  ]
end
```

## Supported endpoints (basically everything)

### Assistants
- modify_assistant: `/assistants/{assistant_id}`
- get_assistant: `/assistants/{assistant_id}`
- delete_assistant: `/assistants/{assistant_id}`
- create_assistant: `/assistants`
- list_assistants: `/assistants`

### Audio
- create_speech: `/audio/speech`
- create_transcription: `/audio/transcriptions`
- create_translation: `/audio/translations`

### Batches
- retrieve_batch: `/batches/{batch_id}`
- create_batch: `/batches`
- list_batches: `/batches`
- cancel_batch: `/batches/{batch_id}/cancel`

### Chat Completions
- get_chat_completion_messages: `/chat/completions/{completion_id}/messages`
- create_chat_completion: `/chat/completions`
- list_chat_completions: `/chat/completions`
- update_chat_completion: `/chat/completions/{completion_id}`
- get_chat_completion: `/chat/completions/{completion_id}`
- delete_chat_completion: `/chat/completions/{completion_id}`

### Completions
- create_completion: `/completions`

### Embeddings
- create_embedding: `/embeddings`

### Files
- retrieve_file: `/files/{file_id}`
- delete_file: `/files/{file_id}`
- download_file: `/files/{file_id}/content`
- create_file: `/files`
- list_files: `/files`

### Fine-tuning
- create_fine_tuning_job: `/fine_tuning/jobs`
- list_paginated_fine_tuning_jobs: `/fine_tuning/jobs`
- retrieve_fine_tuning_job: `/fine_tuning/jobs/{fine_tuning_job_id}`
- list_fine_tuning_events: `/fine_tuning/jobs/{fine_tuning_job_id}/events`
- list_fine_tuning_job_checkpoints: `/fine_tuning/jobs/{fine_tuning_job_id}/checkpoints`
- cancel_fine_tuning_job: `/fine_tuning/jobs/{fine_tuning_job_id}/cancel`

### Images
- create_image_edit: `/images/edits`
- create_image: `/images/generations`
- create_image_variation: `/images/variations`

### Models
- retrieve_model: `/models/{model}`
- delete_model: `/models/{model}`
- list_models: `/models`

### Moderations
- create_moderation: `/moderations`

### Organization
- usage-audio-speeches: `/organization/usage/audio_speeches`
- usage-moderations: `/organization/usage/moderations`
- usage-costs: `/organization/costs`
- usage-vector-stores: `/organization/usage/vector_stores`
- usage-images: `/organization/usage/images`
- admin-api-keys-get: `/organization/admin_api_keys/{key_id}`
- admin-api-keys-delete: `/organization/admin_api_keys/{key_id}`
- modify-project: `/organization/projects/{project_id}`
- retrieve-project: `/organization/projects/{project_id}`
- admin-api-keys-create: `/organization/admin_api_keys`
- admin-api-keys-list: `/organization/admin_api_keys`
- list-project-rate-limits: `/organization/projects/{project_id}/rate_limits`
- create-project: `/organization/projects`
- list-projects: `/organization/projects`
- archive-project: `/organization/projects/{project_id}/archive`
- create-project-service-account: `/organization/projects/{project_id}/service_accounts`
- list-project-service-accounts: `/organization/projects/{project_id}/service_accounts`
- list-audit-logs: `/organization/audit_logs`
- retrieve-project-service-account: `/organization/projects/{project_id}/service_accounts/{service_account_id}`
- delete-project-service-account: `/organization/projects/{project_id}/service_accounts/{service_account_id}`
- retrieve-invite: `/organization/invites/{invite_id}`
- delete-invite: `/organization/invites/{invite_id}`
- usage-completions: `/organization/usage/completions`
- list-project-api-keys: `/organization/projects/{project_id}/api_keys`
- update-project-rate-limits: `/organization/projects/{project_id}/rate_limits/{rate_limit_id}`
- invite_user: `/organization/invites`
- list-invites: `/organization/invites`
- usage-audio-transcriptions: `/organization/usage/audio_transcriptions`
- usage-embeddings: `/organization/usage/embeddings`
- retrieve-project-api-key: `/organization/projects/{project_id}/api_keys/{key_id}`
- delete-project-api-key: `/organization/projects/{project_id}/api_keys/{key_id}`
- list-users: `/organization/users`
- modify-project-user: `/organization/projects/{project_id}/users/{user_id}`
- retrieve-project-user: `/organization/projects/{project_id}/users/{user_id}`
- delete-project-user: `/organization/projects/{project_id}/users/{user_id}`
- create-project-user: `/organization/projects/{project_id}/users`
- list-project-users: `/organization/projects/{project_id}/users`
- modify-user: `/organization/users/{user_id}`
- retrieve-user: `/organization/users/{user_id}`
- delete-user: `/organization/users/{user_id}`
- usage-code-interpreter-sessions: `/organization/usage/code_interpreter_sessions`

### Realtime
- create-realtime-session: `/realtime/sessions`

### Responses
- list_input_items: `/responses/{response_id}/input_items`
- get_response: `/responses/{response_id}`
- delete_response: `/responses/{response_id}`
- create_response: `/responses`

#### Using the Responses API

The Responses API is OpenAI's newest offering that provides a stateful conversation interface with simpler implementation than the Assistants API. It maintains conversation context between requests and allows for easy follow-up interactions.

```elixir
# Create an initial response
{:ok, response} = ExOpenAI.Responses.create_response("tell me a joke", "gpt-4o-mini")

# The response contains the model's reply
IO.puts("Response ID: #{response.id}")
IO.puts("Model used: #{response.model}")
IO.puts("Status: #{response.status}")

# Get the assistant's message
output = List.first(response.output)
IO.puts("Assistant's response: #{output.content |> List.first() |> Map.get(:text)}")

# Continue the conversation by referencing the previous response
{:ok, follow_up} = ExOpenAI.Responses.create_response(
  "Please tell me what I asked you to do in my previous message",
  "gpt-4o-mini",
  previous_response_id: response.id
)

# The model will remember the context from the previous exchange
follow_up_content = follow_up.output
  |> List.first()
  |> Map.get(:content)
  |> List.first()
  |> Map.get(:text)

IO.puts("Follow-up response: #{follow_up_content}")
# Output: "You asked me to tell you a joke. Would you like to hear another one?"
```

The Responses API maintains conversation history automatically when you provide the `previous_response_id` parameter, making it ideal for building conversational applications with minimal state management on your end.

### Threads
- modify_thread: `/threads/{thread_id}`
- get_thread: `/threads/{thread_id}`
- delete_thread: `/threads/{thread_id}`
- create_thread: `/threads`
- list_run_steps: `/threads/{thread_id}/runs/{run_id}/steps`
- submit_tool_ouputs_to_run: `/threads/{thread_id}/runs/{run_id}/submit_tool_outputs`
- get_run_step: `/threads/{thread_id}/runs/{run_id}/steps/{step_id}`
- create_message: `/threads/{thread_id}/messages`
- list_messages: `/threads/{thread_id}/messages`
- create_thread_and_run: `/threads/runs`
- modify_message: `/threads/{thread_id}/messages/{message_id}`
- get_message: `/threads/{thread_id}/messages/{message_id}`
- delete_message: `/threads/{thread_id}/messages/{message_id}`
- cancel_run: `/threads/{thread_id}/runs/{run_id}/cancel`
- create_run: `/threads/{thread_id}/runs`
- list_runs: `/threads/{thread_id}/runs`
- modify_run: `/threads/{thread_id}/runs/{run_id}`
- get_run: `/threads/{thread_id}/runs/{run_id}`

### Uploads
- cancel_upload: `/uploads/{upload_id}/cancel`
- create_upload: `/uploads`
- add_upload_part: `/uploads/{upload_id}/parts`
- complete_upload: `/uploads/{upload_id}/complete`

### Vector Stores
- update_vector_store_file_attributes: `/vector_stores/{vector_store_id}/files/{file_id}`
- get_vector_store_file: `/vector_stores/{vector_store_id}/files/{file_id}`
- delete_vector_store_file: `/vector_stores/{vector_store_id}/files/{file_id}`
- get_vector_store_file_batch: `/vector_stores/{vector_store_id}/file_batches/{batch_id}`
- create_vector_store: `/vector_stores`
- list_vector_stores: `/vector_stores`
- list_files_in_vector_store_batch: `/vector_stores/{vector_store_id}/file_batches/{batch_id}/files`
- create_vector_store_file: `/vector_stores/{vector_store_id}/files`
- list_vector_store_files: `/vector_stores/{vector_store_id}/files`
- retrieve_vector_store_file_content: `/vector_stores/{vector_store_id}/files/{file_id}/content`
- create_vector_store_file_batch: `/vector_stores/{vector_store_id}/file_batches`
- modify_vector_store: `/vector_stores/{vector_store_id}`
- get_vector_store: `/vector_stores/{vector_store_id}`
- delete_vector_store: `/vector_stores/{vector_store_id}`
- search_vector_store: `/vector_stores/{vector_store_id}/search`
- cancel_vector_store_file_batch: `/vector_stores/{vector_store_id}/file_batches/{batch_id}/cancel`

### Editor features: Autocomplete, specs, docs

#### Autocompletion/type-hinting through LSP / ElixirSense

<img src="images/autocomplete.png" width="500" />

#### Typechecking and diagnostics through strict @spec definitions

<img src="images/diagnostics.png" width="500" />

#### Inline docs and signatures thanks to @spec and @doc

<img src="images/functiondocs.png" width="600" />

## To Do's / What's not working yet

- Streams don't have complete typespecs yet

## Configuration

```elixir
import Config

config :ex_openai,
  # find it at https://platform.openai.com/account/api-keys
  api_key: System.get_env("OPENAI_API_KEY"),
  # find it at https://platform.openai.com/account/api-keys
  organization_key: System.get_env("OPENAI_ORGANIZATION_KEY"),
	# optional, other clients allow overriding via the OPENAI_API_URL/OPENAI_API_BASE environment variable,
	# if unset the the default is https://api.openai.com/v1
  base_url: System.get_env("OPENAI_API_URL"),
  # optional, passed to [HTTPoison.Request](https://hexdocs.pm/httpoison/HTTPoison.Request.html) options
  http_options: [recv_timeout: 50_000],
  # optional, default request headers. The following header is required for Assistant endpoints, which are in beta as of December 2023.
  http_headers: [
    {"OpenAI-Beta", "assistants=v2"}
  ],
  # optional http client, useful for testing purposes on dependent projects
  # if unset the default client is ExOpenAI.Client
  http_client: ExOpenAI.Client
```

You can also pass `base_url`, `api_key` and `organization_key` directly by passing them into the `opts` argument when calling the openai apis:

```elixir
ExOpenAI.Models.list_models(openai_api_key: "abc", openai_organization_key: "def", base_url: "https://cheapai.local")
```

## Usage

Make sure to checkout the docs: https://hexdocs.pm/ex_openai

```elixir
ExOpenAI.Models.list_models
{:ok,
 %{
   data: [
     %{
       "created": 1649358449,
       "id": "babbage",
       "object": "model",
       "owned_by": "openai",
       "parent": nil,
       "permission": [
         %{
           "allow_create_engine": false,
           "allow_fine_tuning": false,
           "allow_logprobs": true,
           "allow_sampling": true,
           "allow_search_indices": false,
           "allow_view": true,
           "created": 1669085501,
           "group": nil,
           "id": "modelperm-49FUp5v084tBB49tC4z8LPH5",
           "is_blocking": false,
           "object": "model_permission",
           "organization": "*"
         }
       ],
       "root": "babbage"
     },
  ...
```

Required parameters are converted into function arguments, optional parameters into the opts keyword list:

```elixir
ExOpenAI.Completions.create_completion "text-davinci-003", "The sky is"
{:ok,
 %{
   choices: [
     %{
       "finish_reason": "length",
       "index": 0,
       "logprobs": nil,
       "text": " blue\n\nThe sky is a light blue hue that may have a few white"
     }
   ],
   created: 1677929239,
   id: "cmpl-6qKKllDPsQRtyJ5oHTbkQVS9w7iKM",
   model: "text-davinci-003",
   object: "text_completion",
   usage: %{
     "completion_tokens": 16,
     "prompt_tokens": 3,
     "total_tokens": 19
   }
 }}
```

### Using ChatGPT APIs

```elixir
msgs = [
  %ExOpenAI.Components.ChatCompletionRequestUserMessage{role: :user, content: "Hello!"},
  %ExOpenAI.Components.ChatCompletionRequestAssistantMessage{role: :assistant, content: "What's up?"},
  %ExOpenAI.Components.ChatCompletionRequestUserMessage{role: :user, content: "What ist the color of the sky?"}
]

{:ok, res} =
  ExOpenAI.Chat.create_chat_completion(msgs, "gpt-3.5-turbo",
    logit_bias: %{
      "8043" => -100
    }
  )
```

### Using Assistant APIs

```elixir
{:ok, assistant} =
	ExOpenAI.Assistants.create_assistant(:"gpt-4o",
		name: "Math Teacher",
		instruction:
			"You are a personal math tutor. Write and run code to answer math questions.",
		tools: [%{type: "code_interpreter"}]
	)

{:ok, thread} = ExOpenAI.Threads.create_thread()

{:ok, _msg} =
	ExOpenAI.Threads.create_message(
		thread.id,
		"I need to solve the equation `3x + 11 = 14`. Can you help me?",
		"user"
	)

{:ok, _run} =
	ExOpenAI.Threads.create_run(
		thread.id,
		assistant.id
	)

# sleep for 5 seconds
# :timer.sleep(5000)

{:ok, messages} = ExOpenAI.Threads.list_messages(thread.id)
```

### Usage of endpoints that require files to upload

Load your file into memory, then pass it into the file parameter

```elixir
duck = File.read!("#{__DIR__}/testdata/duck.png")

{:ok, res} = ExOpenAI.Images.create_image_variation(duck)

IO.inspect(res.data)
```

#### File endpoints that require filename information (Audio transcription)

Some endpoints (like audio transcription) require the original filename so the API knows what the encoding of something is. You can pass a `{filename, bitstring}` tuple into anything that requires a file:

```elixir
audio = File.read!("/Users/david/Downloads/output.wav")
output = ExOpenAI.Audio.create_transcription {"foobar.wav", audio}, "whisper-1"

IO.inspect(output)

{:ok,
 %ExOpenAI.Components.CreateTranscriptionResponse{
   text: "Hello, hello, hello, just a test."
 }}
```

### Usage of Audio related

### Streaming data

![streaming](https://github.com/dvcrn/chatgpt-ui/blob/main/demo.gif?raw=true)

You have 2 options to stream data, either by specifying a **callback function** or by specifying a **separate PID**

#### Streaming with a callback function

Pass a callback function to `stream_to` when invoking a call and set `stream:` to `true`:

```elixir
callback = fn
	:finish -> IO.puts "Done"
	{:data, data} -> IO.puts "Data: #{inspect(data)}"
	{:error, err} -> IO.puts "Error: #{inspect(err)}"
end

ExOpenAI.Completions.create_completion "text-davinci-003", "hello world", stream: true, stream_to: callback
```

#### Streaming with a separate process

Create a new client for receiving the streamed data with `use ExOpenAI.StreamingClient`. You'll have to implement the `@behaviour ExOpenAI.StreamingClient` which defines 3 callback functions:

```elixir
defmodule MyStreamingClient do
  use ExOpenAI.StreamingClient

  @impl true
  # callback on data
  def handle_data(data, state) do
    IO.puts("got data: #{inspect(data)}")
    {:noreply, state}
  end

  @impl true
  # callback on error
  def handle_error(e, state) do
    IO.puts("got error: #{inspect(e)}")
    {:noreply, state}
  end

  @impl true
  # callback on finish
  def handle_finish(state) do
    IO.puts("finished!!")
    {:noreply, state}
  end
end
```

Then use it in requests that support streaming by setting `stream: true` and specifying `stream_to: pid`:

```elixir
{:ok, pid} = MyStreamingClient.start_link nil
ExOpenAI.Completions.create_completion "text-davinci-003", "hello world", stream: true, stream_to: pid
```

Your client will now receive the streamed chunks

#### Caveats

- Type information for streamed data is not correct yet. For Completions.create_completion it's fine, however Chat.create_chat_completion requests use a different struct with a `delta` field
- Return types for when setting `stream: true` is incorrect, dialyzer may complain

## How to update once OpenAI changes something?

Run `mix update_openai_docs` and commit the new `docs.yaml` file

## Some stuff built using this SDK (add yours with a PR!)

- [Elixir ChatGPT](https://github.com/dvcrn/elixir-chatgpt)
- https://fixmyjp.d.sh
- https://github.com/dvcrn/gpt-slack-bot
- https://david.coffee/mini-chatgpt-in-elixir-and-genserver/

## How auto-generation works / how can I extend this?

The code got a little complicated but here is the basic gist of it: `codegen.ex` is responsible for parsing the docs.yml file into Elixir types. This is then used in `ex_openai.ex` to generate modules.

The endpoint path is used to generate the group name, for example "/completions" turns into `ExOpenAI.Completions.*`.

1. "parse_component_schema" parses the entire docs.yml file and spits out a bunch of "property" structs that look like this:

```yml
ChatCompletionRequestMessage:
  type: object
  properties:
    role:
      type: string
      enum: ["system", "user", "assistant", "function"]
      description: The role of the messages author. One of `system`, `user`, `assistant`, or `function`.
    content:
      type: string
      nullable: true
      description: The contents of the message. `content` is required for all messages, and may be null for assistant messages with function calls.
    name:
      type: string
      description: The name of the author of this message. `name` is required if role is `function`, and it should be the name of the function whose response is in the `content`. May contain a-z, A-Z, 0-9, and underscores, with a maximum length of 64 characters.
  required:
    - role
    - content
```

... turns into:

```elixir
%{
  description: "",
	kind: :component, # can be 'oneOf' or 'component'
  required_props: [
    %{
      name: "content",
      type: "string",
      description: "The contents of the message. `content` is required for all messages, and may be null for assistant messages with function calls.",
      example: ""
    },
    %{
      name: "role",
      type: {:enum, [:system, :user, :assistant, :function]},
      description: "The role of the messages author. One of `system`, `user`, `assistant`, or `function`.",
      example: ""
    }
  ],
  optional_props: [
    %{
      name: "name",
      type: "string",
      description: "The name of the author of this message. `name` is required if role is `function`, and it should be the name of the function whose response is in the `content`. May contain a-z, A-Z, 0-9, and underscores, with a maximum length of 64 characters.",
      example: ""
    }
  ]
}
```

Important point here: "type" is parsed into an elixir representation that we can work with later. For example `string` -> `string`, or `enum: ["system", "user", "assistant", "function"]` -> `{:enum, [:system, :user, :assistant, :function]}`

2. Type gets constructed by calling `parse_type` from the property parsing. This is a Elixir function with different pattern matching, for example, enum looks like this:

```elixir
  def parse_type(%{"type" => "string", "enum" => enum_entries}),
    do: {:enum, Enum.map(enum_entries, &String.to_atom/1)}
```

3. The final type is converted into a Elixir typespec by calling `type_to_spec`:

```elixir
  def type_to_spec({:enum, l}) when is_list(l) do
    Enum.reduce(l, &{:|, [], [&1, &2]})
  end

  def type_to_spec("number"), do: quote(do: float())
  def type_to_spec("integer"), do: quote(do: integer())
  def type_to_spec("boolean"), do: quote(do: boolean())
```

4. All of this is put together in `ex_openai.ex` to generate the actual modules, the spec is then used to generate documentation.

## License

The package is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Attribution

- Inspired by https://github.com/BlakeWilliams/Elixir-Slack
- Client/config handling from https://github.com/mgallo/openai.ex
