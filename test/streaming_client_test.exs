defmodule ExOpenAI.StreamingClientTest do
  use ExUnit.Case, async: true
  
  alias ExOpenAI.StreamingClient
  
  require Logger
  
  # Mock implementation of a streaming client for testing
  defmodule TestStreamingClient do
    use ExOpenAI.StreamingClient
    
    def handle_data(data, state) do
      send(state.test_pid, {:data, data})
      {:noreply, state}
    end
    
    def handle_error(error, state) do
      send(state.test_pid, {:error, error})
      {:noreply, state}
    end
    
    def handle_finish(state) do
      send(state.test_pid, :finish)
      {:noreply, state}
    end
  end
  
  setup do
    # Create a simple conversion function for testing
    convert_fx = fn
      {:ok, data} -> {:ok, data}
      {:error, err} -> {:error, err}
    end
    
    # Start the streaming client with the test process as the receiver
    {:ok, client} = StreamingClient.start_link(self(), convert_fx)
    
    %{client: client}
  end
  
  describe "handle_info for AsyncChunk" do
    test "handles complete JSON error response", %{client: client} do
      # Create an error response similar to the one in the example
      error_chunk = %HTTPoison.AsyncChunk{
        chunk: ~s({
          "error": {
            "message": "Incorrect API key provided",
            "type": "invalid_request_error",
            "param": null,
            "code": "invalid_api_key"
          }
        }\n),
        id: make_ref()
      }
      
      # Send the chunk to the client
      send(client, error_chunk)
      
      # Assert that the error was forwarded to the test process
      assert_receive {:"$gen_cast", {:error, error_data}}, 500
      assert error_data["message"] == "Incorrect API key provided"
      assert error_data["code"] == "invalid_api_key"
    end
    
    test "handles SSE formatted messages", %{client: client} do
      # Create an SSE formatted chunk
      sse_chunk = %HTTPoison.AsyncChunk{
        chunk: ~s(data: {"id":"chatcmpl-123","object":"chat.completion.chunk","choices":[{"delta":{"content":"Hello"},"index":0}]}\n\n),
        id: make_ref()
      }
      
      # Send the chunk to the client
      send(client, sse_chunk)
      
      # Assert that the data was extracted and forwarded
      assert_receive {:"$gen_cast", {:data, data}}, 500
      assert data["choices"]
    end
    
    test "handles multiple SSE messages in one chunk", %{client: client} do
      # Create a chunk with multiple SSE messages
      multi_sse_chunk = %HTTPoison.AsyncChunk{
        chunk: ~s(data: {"id":"chatcmpl-123","choices":[{"delta":{"content":"Hello"},"index":0}]}\n\n) <>
               ~s(data: {"id":"chatcmpl-123","choices":[{"delta":{"content":" world"},"index":0}]}\n\n),
        id: make_ref()
      }
      
      # Send the chunk to the client
      send(client, multi_sse_chunk)
      
      # Assert that both messages were processed
      assert_receive {:"$gen_cast", {:data, _data1}}, 500
      assert_receive {:"$gen_cast", {:data, _data2}}, 500
    end
    
    test "handles [DONE] message", %{client: client} do
      # Create a chunk with a [DONE] message
      done_chunk = %HTTPoison.AsyncChunk{
        chunk: ~s(data: [DONE]\n\n),
        id: make_ref()
      }
      
      # Send the chunk to the client
      send(client, done_chunk)
      
      # Assert that the finish message was sent
      assert_receive {:"$gen_cast", :finish}, 500
    end
    
    test "handles incomplete chunks and buffers them", %{client: client} do
      # Send an incomplete chunk
      incomplete_chunk1 = %HTTPoison.AsyncChunk{
        chunk: ~s(data: {"id":"chatcmpl-123","choices":[{"delta":{"content":"Hello),
        id: make_ref()
      }
      
      send(client, incomplete_chunk1)
      
      # No data should be received yet
      refute_receive {:"$gen_cast", {:data, _}}, 100
      
      # Send the rest of the chunk
      incomplete_chunk2 = %HTTPoison.AsyncChunk{
        chunk: ~s("},"index":0}]}\n\n),
        id: make_ref()
      }
      
      send(client, incomplete_chunk2)
      
      # Now we should receive the complete data
      assert_receive {:"$gen_cast", {:data, _data}}, 500
    end
  end
  
  describe "handle_info for other messages" do
    test "handles HTTPoison.Error", %{client: client} do
      # Create an error message
      error_msg = %HTTPoison.Error{reason: "test error reason"}
      
      # Send the error to the client
      send(client, error_msg)
      
      # Assert that the error was forwarded
      assert_receive {:"$gen_cast", {:error, "test error reason"}}, 500
    end
    
    test "handles HTTPoison.AsyncStatus with error code", %{client: client} do
      # Create a status message with an error code
      status_msg = %HTTPoison.AsyncStatus{code: 401, id: make_ref()}
      
      # Send the status to the client
      send(client, status_msg)
      
      # Assert that the error was forwarded
      assert_receive {:"$gen_cast", {:error, "received error status code: 401"}}, 500
    end
    
    test "handles HTTPoison.AsyncStatus with success code", %{client: client} do
      # Create a status message with a success code
      status_msg = %HTTPoison.AsyncStatus{code: 200, id: make_ref()}
      
      # Send the status to the client
      send(client, status_msg)
      
      # No error should be forwarded
      refute_receive {:"$gen_cast", {:error, _}}, 100
    end
  end
  
  test "integration with TestStreamingClient" do
    # Start a TestStreamingClient with the test process
    {:ok, test_client} = TestStreamingClient.start_link(%{test_pid: self()})
    
    # Send a data message
    GenServer.cast(test_client, {:data, "test data"})
    
    # Assert that the data was handled
    assert_receive {:data, "test data"}, 500
    
    # Send an error message
    GenServer.cast(test_client, {:error, "test error"})
    
    # Assert that the error was handled
    assert_receive {:error, "test error"}, 500
    
    # Send a finish message
    GenServer.cast(test_client, :finish)
    
    # Assert that the finish was handled
    assert_receive :finish, 500
  end
  
  # Test for the buffer handling with complete messages
  test "handles complete messages correctly when buffer ends with \\n\\n", %{client: client} do
    # Create a chunk with a complete message (ending with \n\n)
    complete_chunk = %HTTPoison.AsyncChunk{
      chunk: ~s(data: {"id":"chatcmpl-123","choices":[{"delta":{"content":"Complete message"},"index":0}]}\n\n),
      id: make_ref()
    }
    
    # Send the chunk to the client
    send(client, complete_chunk)
    
    # Assert that the message was processed
    assert_receive {:"$gen_cast", {:data, data}}, 500
    assert get_in(data, ["choices", Access.at(0), "delta", "content"]) == "Complete message"
  end
  
  # Test for handling a real-world error response
  test "handles real-world API error response", %{client: client} do
    # Create an error response based on the example
    error_chunk = %HTTPoison.AsyncChunk{
      chunk: ~s({\n    "error": {\n        "message": "Incorrect API key provided: sk-or-v1*************************************************************78b6. You can find your API key at https://platform.openai.com/account/api-keys.",\n        "type": "invalid_request_error",\n        "param": null,\n        "code": "invalid_api_key"\n    }\n}\n),
      id: make_ref()
    }
    
    # Send the chunk to the client
    send(client, error_chunk)
    
    # Assert that the error was forwarded to the test process
    assert_receive {:"$gen_cast", {:error, error_data}}, 500
    assert error_data["code"] == "invalid_api_key"
    assert String.contains?(error_data["message"], "Incorrect API key provided")
  end
  
  # Test for handling a deprecated model error
  test "handles deprecated model error", %{client: client} do
    # Create an error response for a deprecated model
    error_chunk = %HTTPoison.AsyncChunk{
      chunk: ~s({\n    "error": {\n        "message": "The model `text-davinci-003` has been deprecated, learn more here: https://platform.openai.com/docs/deprecations",\n        "type": "invalid_request_error",\n        "param": null,\n        "code": "model_not_found"\n    }\n}\n),
      id: make_ref()
    }
    
    # Send the chunk to the client
    send(client, error_chunk)
    
    # Assert that the error was forwarded to the test process
    assert_receive {:"$gen_cast", {:error, error_data}}, 500
    assert error_data["code"] == "model_not_found"
    assert String.contains?(error_data["message"], "text-davinci-003")
    assert String.contains?(error_data["message"], "deprecated")
  end
end