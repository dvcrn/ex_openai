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

  def handle_chunk(
        chunk,
        %{stream_to: pid, convert_response_fx: convert_fx}
      ) do
    chunk
    |> String.trim()
    |> case do
      "[DONE]" ->
        GenServer.cast(pid, :finish)

      etc ->
        json =
          Jason.decode(etc)
          |> convert_fx.()

        case json do
          {:ok, res} ->
            GenServer.cast(pid, {:data, res})

          {:error, err} ->
            GenServer.cast(pid, {:error, err})
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
    Logger.debug("Error: #{inspect(reason)}")
    GenServer.cast(state.stream_to, {:error, reason})
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncStatus{} = status, state) do
    Logger.debug("Connection status: #{inspect(status)}")
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
