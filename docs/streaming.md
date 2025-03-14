# Streaming Guide

ExOpenAI supports streaming responses from OpenAI's API, which is particularly useful for chat and completion endpoints. This guide explains how to use streaming effectively in your applications.

## Streaming Options

ExOpenAI provides two methods for handling streaming responses:

1. **Callback Function** - Pass a function that processes each chunk as it arrives
2. **Streaming Client** - Create a dedicated process to handle the stream

## Streaming with a Callback Function

The simplest way to handle streaming is to pass a callback function to the `stream_to` parameter:

```elixir
callback = fn
  :finish -> IO.puts "Stream finished"
  {:data, data} -> IO.puts "Received data: #{inspect(data)}"
  {:error, err} -> IO.puts "Error: #{inspect(err)}"
end

ExOpenAI.Completions.create_completion(
  "gpt-3.5-turbo-instruct", 
  "Tell me a story about a robot", 
  stream: true, 
  stream_to: callback
)
```

The callback function will be called with:
- `{:data, data}` for each chunk of data received
- `{:error, error}` if an error occurs
- `:finish` when the stream completes

## Streaming with a Dedicated Process

For more complex applications, you can create a dedicated process to handle the stream:

1. First, create a module that implements the `ExOpenAI.StreamingClient` behaviour:

```elixir
defmodule MyStreamingClient do
  use ExOpenAI.StreamingClient

  @impl true
  def handle_data(data, state) do
    IO.puts("Received data: #{inspect(data)}")
    # Process the data chunk
    {:noreply, state}
  end

  @impl true
  def handle_error(error, state) do
    IO.puts("Error: #{inspect(error)}")
    # Handle the error
    {:noreply, state}
  end

  @impl true
  def handle_finish(state) do
    IO.puts("Stream finished")
    # Clean up or finalize processing
    {:noreply, state}
  end
end
```

2. Then, start the client and pass its PID to the API call:

```elixir
{:ok, pid} = MyStreamingClient.start_link(initial_state)

ExOpenAI.Chat.create_chat_completion(
  messages,
  "gpt-4",
  stream: true,
  stream_to: pid
)
```

## Example: Building a Chat Interface

Here's a more complete example of using streaming to build a simple chat interface:

```elixir
defmodule ChatInterface do
  use ExOpenAI.StreamingClient

  def start_chat(initial_prompt) do
    {:ok, pid} = __MODULE__.start_link(%{buffer: "", complete_message: ""})
    
    messages = [
      %ExOpenAI.Components.ChatCompletionRequestUserMessage{
        role: :user, 
        content: initial_prompt
      }
    ]
    
    ExOpenAI.Chat.create_chat_completion(
      messages,
      "gpt-4",
      stream: true,
      stream_to: pid
    )
    
    pid
  end
  
  @impl true
  def handle_data(data, state) do
    # Extract the content from the delta if it exists
    content = case data do
      %{choices: [%{"delta" => %{"content" => content}}]} when is_binary(content) -> 
        content
      _ -> 
        ""
    end
    
    # Update the buffer and print the new content
    if content != "" do
      IO.write(content)
      {:noreply, %{state | buffer: state.buffer <> content, complete_message: state.complete_message <> content}}
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
    IO.puts("\n\nChat response complete.")
    # The complete message is now available in state.complete_message
    {:noreply, state}
  end
  
  # Function to get the complete message after streaming is done
  def get_complete_message(pid) do
    :sys.get_state(pid).complete_message
  end
end
```

Usage:

```elixir
# Start a chat
pid = ChatInterface.start_chat("Tell me about quantum computing")

# After the stream completes, get the full message
complete_response = ChatInterface.get_complete_message(pid)
```

## Streaming with Different Endpoints

Most OpenAI endpoints that support streaming work in a similar way, but the structure of the streamed data may differ:

### Chat Completions

```elixir
ExOpenAI.Chat.create_chat_completion(
  messages,
  "gpt-4",
  stream: true,
  stream_to: callback_or_pid
)
```

The streamed data will contain delta updates to the assistant's message.

### Text Completions

```elixir
ExOpenAI.Completions.create_completion(
  "gpt-3.5-turbo-instruct",
  prompt,
  stream: true,
  stream_to: callback_or_pid
)
```

The streamed data will contain text fragments.

## Caveats and Limitations

- Type information for streamed data is not always accurate in the current version
- Return types for streaming requests may not match the actual returned data
- Streaming increases the total number of tokens used slightly compared to non-streaming requests
- Error handling in streaming contexts requires special attention

## Best Practices

1. **Buffer Management**: Always maintain a buffer to reconstruct the complete response
2. **Error Handling**: Implement robust error handling in your streaming clients
3. **Timeouts**: Consider implementing timeouts for long-running streams
4. **Testing**: Test your streaming code with both short and very long responses
5. **State Management**: Design your streaming client's state to handle all the information you need