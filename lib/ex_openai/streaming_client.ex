defmodule ExOpenAI.StreamingClient do
  use GenServer

  require Logger

  @callback handle_data(any(), any()) :: {:noreply, any()}
  @callback handle_finish(any()) :: {:noreply, any()}
  @callback handle_error(any(), any()) :: {:noreply, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour ExOpenAI.StreamingClient

      def start_link(init_args, opts \\ []) do
        GenServer.start_link(__MODULE__, init_args, opts)
      end

      def init(init_args) do
        {:ok, init_args}
      end

      def handle_cast({:data, data}, state) do
        handle_data(data, state)
      end

      def handle_cast({:error, e}, state) do
        handle_error(e, state)
      end

      def handle_cast(:finish, state) do
        handle_finish(state)
      end
    end
  end

  def start_link(stream_to_pid, convert_response_fx) do
    GenServer.start_link(__MODULE__,
      stream_to: stream_to_pid,
      convert_response_fx: convert_response_fx
    )
  end

  def init(stream_to: pid, convert_response_fx: fx) do
    {:ok, %{stream_to: pid, convert_response_fx: fx, buffer: ""}}
  end

  @doc """
  Forwards the given response back to the receiver
  If receiver is a PID, will use GenServer.cast to send
  If receiver is a function, will call the function directly
  """
  def forward_response(pid, data) when is_pid(pid) do
    GenServer.cast(pid, data)
  end

  def forward_response(callback_fx, data) when is_function(callback_fx) do
    callback_fx.(data)
  end

  def handle_chunk(
        chunk,
        %{stream_to: pid_or_fx, convert_response_fx: convert_fx}
      ) do
    chunk
    |> String.trim()
    |> case do
      "[DONE]" ->
        Logger.debug("Received [DONE]")
        forward_response(pid_or_fx, :finish)

      "event: " <> event_type ->
        Logger.debug("Received event: #{inspect(event_type)}")

      ": OPENROUTER PROCESSING" <> event_type ->
        Logger.debug("Received event: #{inspect(event_type)}")

      etc ->
        Logger.debug("Received event payload: #{inspect(etc)}")

        json =
          Jason.decode(etc)
          |> convert_fx.()

        case json do
          {:ok, res} ->
            forward_response(pid_or_fx, {:data, res})

          {:error, err} ->
            Logger.warning("Received something that isn't JSON in stream: #{inspect(etc)}")
            forward_response(pid_or_fx, {:error, err})
        end
    end
  end

  def handle_info(
        %HTTPoison.AsyncChunk{chunk: "data: [DONE]\n\n"} = chunk,
        state
      ) do
    chunk.chunk
    |> String.replace("data: ", "")
    |> handle_chunk(state)

    {:noreply, state}
  end

  def handle_info(
        %HTTPoison.AsyncChunk{chunk: ": OPENROUTER PROCESSING\n\n"},
        state
      ) do
    Logger.debug("received : OPENROUTER PROCESSING stamp")
    {:noreply, state}
  end

  # def handle_info(%HTTPoison.AsyncChunk{chunk: "data: " <> chunk_data}, state) do
  #   Logger.debug("Received AsyncChunk DATA: #{inspect(chunk_data)}")
  # end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, state) do
    Logger.debug("Received AsyncChunk (partial): #{inspect(chunk)}")

    # Combine the existing buffer with the new chunk
    new_buffer = state.buffer <> chunk

    # Check if the buffer contains a complete JSON object (for error cases)
    case is_complete_json(new_buffer) do
      {:ok, json_obj} ->
        # We have a complete JSON object, process it directly
        process_complete_json(json_obj, state)
        # Clear the buffer since we've processed the JSON
        {:noreply, %{state | buffer: ""}}

      :incomplete ->
        # Process SSE format properly
        # First split by double newlines which separate SSE messages
        sse_messages = String.split(new_buffer, "\n\n")

        # Check if the buffer ends with "\n\n" to determine if the last message is complete
        buffer_complete = String.ends_with?(new_buffer, "\n\n")

        # If the buffer ends with "\n\n", all messages are complete
        {messages, incomplete_buffer} =
          case {sse_messages, buffer_complete} do
            {[], _} ->
              {[], ""}

            {messages, true} ->
              # All messages are complete, including the last one
              {messages, ""}

            {messages, false} ->
              # The last message might be incomplete
              last_idx = length(messages) - 1
              {Enum.take(messages, last_idx), Enum.at(messages, last_idx, "")}
          end

        # Process each complete SSE message
        state_after_parse =
          Enum.reduce(messages, state, fn message, st ->
            if String.trim(message) == "" do
              st
            else
              # Parse the SSE message
              message_parts = String.split(message, "\n")

              # Extract event type and data
              {event_type, data} = extract_sse_parts(message_parts)

              case event_type do
                "response.created" ->
                  process_sse_data(data, st)

                "response.in_progress" ->
                  process_sse_data(data, st)

                "response.final" ->
                  process_sse_data(data, st)

                "response.completed" ->
                  process_sse_data(data, st)

                "[DONE]" ->
                  forward_response(st.stream_to, :finish)
                  st

                _ ->
                  # Unknown event type, try to process data anyway
                  process_sse_data(data, st)
              end
            end
          end)

        # Update the buffer in the new state
        new_state = %{state_after_parse | buffer: incomplete_buffer}
        {:noreply, new_state}
    end
  end

  def handle_info(%HTTPoison.Error{reason: reason}, state) do
    Logger.error("Error: #{inspect(reason)}")

    forward_response(state.stream_to, {:error, reason})
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: code} = status, state) do
    Logger.debug("Connection status: #{inspect(status)}")

    if code >= 400 do
      forward_response(state.stream_to, {:error, "received error status code: #{code}"})
    end

    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    # :finish is already sent when data ends
    # TODO: may need a separate event for this
    # forward_response(state.stream_to, :finish)

    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncHeaders{} = headers, state) do
    Logger.debug("Connection headers: #{inspect(headers)}")
    {:noreply, state}
  end

  def handle_info(info, state) do
    Logger.debug("Unhandled info: #{inspect(info)}")
    {:noreply, state}
  end

  # Helper function to extract event type and data from SSE message parts
  defp extract_sse_parts(message_parts) do
    Enum.reduce(message_parts, {nil, nil}, fn part, {event, data} ->
      cond do
        String.starts_with?(part, "event: ") ->
          {String.replace_prefix(part, "event: ", ""), data}

        String.starts_with?(part, "data: ") ->
          {event, String.replace_prefix(part, "data: ", "")}

        true ->
          {event, data}
      end
    end)
  end

  # Process the data part of an SSE message
  defp process_sse_data(nil, state), do: state

  defp process_sse_data(data, state) do
    case data do
      "[DONE]" ->
        forward_response(state.stream_to, :finish)
        state

      _ ->
        case Jason.decode(data) do
          {:ok, decoded} ->
            # Check if the decoded JSON contains an error
            if Map.has_key?(decoded, "error") do
              Logger.warning("Received error in stream: #{inspect(decoded.error)}")
              forward_response(state.stream_to, {:error, decoded.error})
              state
            else
              case state.convert_response_fx.({:ok, decoded}) do
                {:ok, message} ->
                  forward_response(state.stream_to, {:data, message})

                e ->
                  Logger.warning(
                    "Something went wrong trying to decode the response: #{inspect(e)}"
                  )
              end

              state
            end

          {:error, _} ->
            Logger.warning("Received something that isn't valid JSON in stream: #{inspect(data)}")
            state
        end
    end
  end

  # Helper function to check if a string contains a complete JSON object
  defp is_complete_json(str) do
    # Try to parse the string as JSON
    case Jason.decode(str) do
      {:ok, decoded} ->
        # If it's a complete JSON with an error field, return it
        if is_map(decoded) && Map.has_key?(decoded, "error") do
          {:ok, decoded}
        else
          :incomplete
        end

      {:error, _} ->
        :incomplete
    end
  end

  # Process a complete JSON object (typically an error)
  defp process_complete_json(json_obj, state) do
    if Map.has_key?(json_obj, "error") do
      error_data = Map.get(json_obj, "error")
      Logger.warning("Received error in stream: #{inspect(error_data)}")
      forward_response(state.stream_to, {:error, error_data})
    else
      # Handle other types of complete JSON objects if needed
      case state.convert_response_fx.({:ok, json_obj}) do
        {:ok, message} ->
          forward_response(state.stream_to, {:data, message})

        e ->
          Logger.warning("Something went wrong trying to decode the response: #{inspect(e)}")
      end
    end

    state
  end
end
