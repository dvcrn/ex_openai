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

  defp parse_lines(lines, state) do
    # The last element might be incomplete JSON, which we keep.
    # Everything that is valid JSON, we forward immediately.
    {remaining_buffer, updated_state} =
      Enum.reduce(lines, {"", state}, fn line, {partial_acc, st} ->
        # Reconstruct the current attempt: partial data + the current line
        attempt = (partial_acc <> line) |> String.trim()

        cond do
          attempt == "[DONE]" ->
            Logger.debug("Received [DONE]")
            forward_response(st.stream_to, :finish)
            {"", st}

          attempt == "" ->
            # Possibly just an empty line or leftover
            {"", st}

          true ->
            # Attempt to parse
            case Jason.decode(attempt) do
              {:ok, decoded} ->
                # Once successfully decoded, forward, and reset partial buffer
                case st.convert_response_fx.({:ok, decoded}) do
                  {:ok, message} ->
                    forward_response(st.stream_to, {:data, message})

                  e ->
                    Logger.warning(
                      "Something went wrong trying to decode the response: #{inspect(e)}"
                    )
                end

                {"", st}

              {:error, _} ->
                # Not valid JSON yet; treat entire attempt as partial
                {attempt, st}
            end
        end
      end)

    {remaining_buffer, updated_state}
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

  # def handle_info(%HTTPoison.AsyncChunk{chunk: "data: " <> chunk_data}, state) do
  #   Logger.debug("Received AsyncChunk DATA: #{inspect(chunk_data)}")
  # end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, state) do
    Logger.debug("Received AsyncChunk (partial): #{inspect(chunk)}")

    # Combine the existing buffer with the new chunk
    new_buffer = state.buffer <> chunk

    # Split by "data:" lines, but be mindful of partial JSON
    lines =
      new_buffer
      |> String.split(~r/data: /)

    # The first chunk might still hold partial data from the end
    # or the last chunk might be partial data at the end.

    # We'll need a function that attempts to parse each line. If it fails, we store
    # that line back to the buffer for the next chunk.
    {remaining_buffer, state_after_parse} = parse_lines(lines, state)

    # Update the buffer in the new state
    new_state = %{state_after_parse | buffer: remaining_buffer}
    {:noreply, new_state}
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
end
