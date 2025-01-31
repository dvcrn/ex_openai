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
    {:ok, %{stream_to: pid, convert_response_fx: fx}}
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

      etc ->
        Logger.debug("Received event payload: #{inspect(etc)}")

        json =
          Jason.decode(etc)
          |> convert_fx.()

        case json do
          {:ok, res} ->
            forward_response(pid_or_fx, {:data, res})

          {:error, err} ->
            Logger.warn("Received something that isn't JSON in stream: #{inspect(etc)}")
            # forward_response(pid_or_fx, {:error, err})
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
        %HTTPoison.AsyncChunk{chunk: chunk},
        state
      ) do
    chunk
    |> String.trim()
    |> String.split("data:")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.each(fn subchunk ->
      handle_chunk(subchunk, state)
    end)

    {:noreply, state}
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
