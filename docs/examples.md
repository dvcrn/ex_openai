# ExOpenAI Usage Examples

This document provides practical examples of using ExOpenAI for various common tasks.

## Table of Contents

- [Chat Completions](#chat-completions)
- [Assistants API](#assistants-api)
- [Image Generation](#image-generation)
- [Audio Processing](#audio-processing)
- [Embeddings](#embeddings)
- [File Management](#file-management)
- [Responses API](#responses-api)
- [Streaming Examples](#streaming-examples)

## Chat Completions

### Basic Chat Completion

```elixir
messages = [
  %ExOpenAI.Components.ChatCompletionRequestUserMessage{
    role: :user,
    content: "What is the capital of France?"
  }
]

{:ok, response} = ExOpenAI.Chat.create_chat_completion(messages, "gpt-4")

# Extract the assistant's response
assistant_message = response.choices |> List.first() |> Map.get("message") |> Map.get("content")
IO.puts("Assistant: #{assistant_message}")
```

### Multi-turn Conversation

```elixir
messages = [
  %ExOpenAI.Components.ChatCompletionRequestSystemMessage{
    role: :system,
    content: "You are a helpful assistant that speaks like a pirate."
  },
  %ExOpenAI.Components.ChatCompletionRequestUserMessage{
    role: :user,
    content: "Tell me about the weather today."
  },
  %ExOpenAI.Components.ChatCompletionRequestAssistantMessage{
    role: :assistant,
    content: "Arr matey! The skies be clear and the winds be favorable today!"
  },
  %ExOpenAI.Components.ChatCompletionRequestUserMessage{
    role: :user,
    content: "What should I wear?"
  }
]

{:ok, response} = ExOpenAI.Chat.create_chat_completion(messages, "gpt-4")
```

### Using Function Calling

```elixir
messages = [
  %ExOpenAI.Components.ChatCompletionRequestUserMessage{
    role: :user,
    content: "What's the weather like in San Francisco?"
  }
]

tools = [
  %{
    type: "function",
    function: %{
      name: "get_weather",
      description: "Get the current weather in a given location",
      parameters: %{
        type: "object",
        properties: %{
          location: %{
            type: "string",
            description: "The city and state, e.g. San Francisco, CA"
          },
          unit: %{
            type: "string",
            enum: ["celsius", "fahrenheit"],
            description: "The temperature unit to use"
          }
        },
        required: ["location"]
      }
    }
  }
]

{:ok, response} =
  ExOpenAI.Chat.create_chat_completion(
    messages,
    "gpt-4",
    tools: tools,
    tool_choice: "auto"
  )

# Handle the function call
case response.choices |> List.first() |> Map.get(:message) do
  %{:tool_calls => tool_calls} ->
    # Process tool calls
    Enum.each(tool_calls, fn tool_call ->
      IO.puts("Tool call: #{inspect(tool_call)}")

      function_name = tool_call.function.name
      arguments = Jason.decode!(tool_call.function.arguments)

      IO.puts("function arguments: #{inspect(arguments)}")

      # Call your actual function
      weather_data = %{"weather" => "its very very very hot"}

      # Add the function response to messages
      updated_messages =
        messages ++
          [
            %ExOpenAI.Components.ChatCompletionRequestAssistantMessage{
              role: :assistant,
              tool_calls: tool_calls
            },
            %ExOpenAI.Components.ChatCompletionRequestToolMessage{
              role: :tool,
              tool_call_id: tool_call.id,
              content: Jason.encode!(weather_data)
            }
          ]

      # Get the final response
      {:ok, final_response} =
        ExOpenAI.Chat.create_chat_completion(
          updated_messages,
          "gpt-4"
        )

      IO.puts(
        "Final response: #{final_response.choices |> List.first() |> Map.get(:message) |> Map.get(:content)}"
      )
    end)

  e ->
    # Regular message response
    IO.inspect(e)

    IO.puts(
      "Response: #{response.choices |> List.first() |> Map.get(:message) |> Map.get(:content)}"
    )
end
```

## Assistants API

### Creating and Using an Assistant

```elixir
# Create an assistant
IO.puts("Creating assistant")

{:ok, assistant} =
  ExOpenAI.Assistants.create_assistant(
    :"gpt-4o",
    name: "Research Assistant",
    instructions: "You help users with research questions. Be thorough and cite sources.",
    tools: [%{type: "file_search"}]
  )

# Create a thread
IO.puts("Creating thread")
{:ok, thread} = ExOpenAI.Threads.create_thread()

# Add a message to the thread
IO.puts("Creating message")

{:ok, message} =
  ExOpenAI.Threads.create_message(
    thread.id,
    "Can you explain the basics of quantum computing?",
    "user"
  )

# Run the assistant on the thread
IO.puts("Running assistant #{inspect(assistant.id)} with thread #{inspect(thread.id)}")

{:ok, run} =
  ExOpenAI.Threads.create_run(
    thread.id,
    assistant.id
  )

# Poll for completion
check_run_status = fn run_id, thread_id ->
  {:ok, run_status} = ExOpenAI.Threads.get_run(thread_id, run_id)
  run_status.status
end

# Wait for completion (in a real app, use a better polling mechanism)
run_id = run.id
thread_id = thread.id

# simple loop to wait until status is no longer in_progress
wait_for_completion = fn wait_func, run_id, thread_id ->
  case check_run_status.(run_id, thread_id) do
    "completed" ->
      # Get the messages
      {:ok, messages} = ExOpenAI.Threads.list_messages(thread_id)
      latest_message = messages.data |> List.first()

      IO.puts(
        "Assistant response: #{latest_message.content |> List.first() |> Map.get("text")}"
      )

      IO.inspect(latest_message)

    "failed" ->
      IO.puts("Run failed")

    "queued" ->
      IO.puts("Run is queued... ")
      Process.sleep(2000)
      wait_func.(wait_func, run_id, thread_id)

    "in_progress" ->
      IO.puts("Run is still in progress, waiting 2s")
      Process.sleep(2000)
      wait_func.(wait_func, run_id, thread_id)

    "requires_action" ->
      # Handle tool calls if needed
      {:ok, run_details} = ExOpenAI.Threads.get_run(thread_id, run_id)

      # tool_outputs =
      #   process_tool_calls(run_details.required_action.submit_tool_outputs.tool_calls)

      {:ok, _updated_run} =
        ExOpenAI.Threads.submit_tool_ouputs_to_run(
          thread_id,
          run_id,
          %{}
          # tool_outputs
        )

    status ->
      IO.puts("Run is still in progress: #{status}")
  end
end

wait_for_completion.(wait_for_completion, run_id, thread_id)
```

## Image Generation

### Generate an Image

```elixir
{:ok, response} = ExOpenAI.Images.create_image(
  "A serene lake surrounded by mountains at sunset",
  n: 1,
  size: "1024x1024"
)

# Get the image URL
image_url = response.data |> List.first() |> IO.inspect
```

### Edit an Image

```elixir
# Read the image and mask files
image_data = File.read!("path/to/image.png")
mask_data = File.read!("path/to/mask.png")

{:ok, response} = ExOpenAI.Images.create_image_edit(
  image_data,
  mask_data,
  "Replace the masked area with a cat",
  n: 1,
  size: "1024x1024"
)

# Get the edited image URL
edited_image_url = response.data |> List.first() |> IO.inspect
```

### Create Image Variations

```elixir
image_data = File.read!("path/to/image.png")

{:ok, response} = ExOpenAI.Images.create_image_variation(
  image_data,
  n: 3,
  size: "1024x1024"
)

# Get all variation URLs
IO.inspect(response)
```

## Audio Processing

### Transcribe Audio

```elixir
audio_data = File.read!("path/to/audio.mp3")

{:ok, transcription} = ExOpenAI.Audio.create_transcription(
  {"audio.mp3", audio_data},
  "whisper-1"
)

IO.inspect(transcription)
```

### Translate Audio

```elixir
audio_data = File.read!("path/to/french_audio.mp3")

{:ok, translation} = ExOpenAI.Audio.create_translation(
  {"french_audio.mp3", audio_data},
  "whisper-1"
)

IO.inspect(translation)
```

### Generate Speech

```elixir
{:ok, speech_data} = ExOpenAI.Audio.create_speech(
  "Hello world! This is a test of the text-to-speech API.",
  "tts-1",
  :alloy,
  response_format: "mp3"
)

IO.inspect(speech_data)

# Save the audio file
File.write!("output.mp3", speech_data)
```

## Embeddings

### Create Embeddings for Text

```elixir
{:ok, response} = ExOpenAI.Embeddings.create_embedding(
  "The food was delicious and the service was excellent.",
  "text-embedding-ada-002"
)

# Get the embedding vector
embedding_vector = response.data |> List.first() |> IO.inspect
```

### Create Embeddings for Multiple Texts

```elixir
texts = [
  "The food was delicious and the service was excellent.",
  "The restaurant was too noisy and the food was mediocre.",
  "I would definitely recommend this place to my friends."
]

{:ok, response} = ExOpenAI.Embeddings.create_embedding(
  texts,
  "text-embedding-ada-002"
)

# Get all embedding vectors
IO.inspect(response)
```

## File Management

### Upload a File

```elixir
file_content = File.read!("path/to/data.jsonl")

{:ok, file} = ExOpenAI.Files.create_file(
  file_content,
  "fine-tune"
)

IO.puts("File ID: #{file.id}")
```

### List Files

```elixir
{:ok, files} = ExOpenAI.Files.list_files()

Enum.each(files.data, fn file ->
  IO.puts("File ID: #{file["id"]}, Filename: #{file["filename"]}, Purpose: #{file["purpose"]}")
end)
```

### Retrieve File Content

```elixir
{:ok, content} = ExOpenAI.Files.download_file(file_id)
```

### Delete a File

```elixir
{:ok, result} = ExOpenAI.Files.delete_file(file_id)
IO.puts("File deleted: #{result.deleted}")
```

## Responses API

### Create a Response

```elixir
{:ok, response} = ExOpenAI.Responses.create_response(
  "Tell me a joke about programming",
  "gpt-4o-mini"
)

# Get the assistant's message
output = List.first(response.output)
content = output.content |> List.first() |> Map.get(:text)
IO.puts("Assistant's response: #{content}")
```

### Continue a Conversation

```elixir
# Initial response
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

# Get the follow-up response
follow_up_content = follow_up.output
  |> List.first()
  |> Map.get(:content)
  |> List.first()
  |> Map.get(:text)

IO.puts("Follow-up response: #{follow_up_content}")
```

## Streaming Examples

### Streaming Chat Completion

```elixir
defmodule ChatStreamer do
  use ExOpenAI.StreamingClient

  def start(messages, model) do
    {:ok, pid} = __MODULE__.start_link(%{text: ""})

    ExOpenAI.Chat.create_chat_completion(
      messages,
      model,
      stream: true,
      stream_to: pid
    )

    pid
  end

  @impl true
  def handle_data(data, state) do
    content = case data do
      %{choices: [%{"delta" => %{"content" => content}}]} when is_binary(content) ->
        content
      _ ->
        ""
    end

    if content != "" do
      IO.write(content)
      {:noreply, %{state | text: state.text <> content}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_error(error, state) do
    IO.puts("\nError: #{inspect(error)}")
    {:noreply, state}
  end

  @impl true
  def handle_finish(state) do
    IO.puts("\n\nDone!")
    {:noreply, state}
  end

  def get_full_text(pid) do
    :sys.get_state(pid).text
  end
end

# Usage
messages = [
  %ExOpenAI.Components.ChatCompletionRequestUserMessage{
    role: :user,
    content: "Write a short poem about coding"
  }
]

pid = ChatStreamer.start(messages, "gpt-4")

# After streaming completes
full_text = ChatStreamer.get_full_text(pid)
```

### Streaming with a Callback Function

```elixir
buffer = ""
ref = make_ref()

callback = fn
  :finish ->
    send(self(), {:stream_finished, ref, buffer})

  {:data, data} ->
    content = case data do
      %{choices: [%{"delta" => %{"content" => content}}]} when is_binary(content) ->
        content
      _ ->
        ""
    end

    if content != "" do
      IO.write(content)
      buffer = buffer <> content
    end

  {:error, err} ->
    IO.puts("\nError: #{inspect(err)}")
end

messages = [
  %ExOpenAI.Components.ChatCompletionRequestUserMessage{
    role: :user,
    content: "Explain quantum computing briefly"
  }
]

ExOpenAI.Chat.create_chat_completion(
  messages,
  "gpt-4",
  stream: true,
  stream_to: callback
)

# In a real application, you would wait for the {:stream_finished, ref, buffer} message
```
