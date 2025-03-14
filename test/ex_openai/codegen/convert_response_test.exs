defmodule ExOpenAI.Codegen.ConvertResponseTest do
  use ExUnit.Case, async: false
  alias ExOpenAI.Codegen

  # Define test components in a way that they won't be mocked
  defmodule TestComponent do
    defstruct [:id, :name, :value]

    def unpack_ast, do: nil
  end

  defmodule AnotherTestComponent do
    defstruct [:id, :type, :data]

    def unpack_ast, do: nil
  end

  # Create a test-specific version of string_to_component
  defp test_string_to_component("TestComponent"), do: TestComponent
  defp test_string_to_component("AnotherTestComponent"), do: AnotherTestComponent
  defp test_string_to_component(other), do: Module.concat(ExOpenAI.Components, other)

  # Create a wrapper for convert_response that uses our test_string_to_component
  defp test_convert_response(response, response_type) do
    # Store original function
    original_fn = &Codegen.string_to_component/1
    
    try do
      # Replace with our test function
      :meck.new(Codegen, [:passthrough])
      :meck.expect(Codegen, :string_to_component, &test_string_to_component/1)
      
      # Call the function
      Codegen.convert_response(response, response_type)
    after
      # Clean up
      :meck.unload(Codegen)
    end
  end

  describe "convert_response/2" do
    test "handles response with 'response' and 'type' keys" do
      response = {:ok, %{"response" => %{"id" => "123", "name" => "test"}, "type" => "some_type"}}
      result = test_convert_response(response, nil)
      assert result == {:ok, %{"id" => "123", "name" => "test"}}
    end

    test "passes through reference values unchanged" do
      ref = make_ref()
      response = {:ok, ref}
      result = test_convert_response(response, nil)
      assert result == {:ok, ref}
    end

    test "returns original response when response_type is nil" do
      response = {:ok, %{"id" => "123", "name" => "test"}}
      result = test_convert_response(response, nil)
      assert result == {:ok, %{"id" => "123", "name" => "test"}}
    end

    test "converts response to component struct when keys match" do
      response = {:ok, %{"id" => "123", "name" => "test", "value" => 42}}
      result = test_convert_response(response, {:component, "TestComponent"})
      
      # Check that we got a TestComponent struct with the expected values
      assert match?({:ok, %TestComponent{}}, result)
      {:ok, struct} = result
      assert struct.id == "123"
      assert struct.name == "test"
      assert struct.value == 42
    end

    test "returns original response when no keys match the component" do
      response = {:ok, %{"foo" => "bar", "baz" => "qux"}}
      result = test_convert_response(response, {:component, "TestComponent"})
      assert result == {:ok, %{"foo" => "bar", "baz" => "qux"}}
    end

    test "handles oneOf with multiple possible components - best match wins" do
      # This response has more keys matching TestComponent than AnotherTestComponent
      response = {:ok, %{"id" => "123", "name" => "test", "value" => 42, "extra" => "ignored"}}
      result = test_convert_response(response, {:oneOf, [{:component, "TestComponent"}, {:component, "AnotherTestComponent"}]})
      
      assert match?({:ok, %TestComponent{}}, result)
      {:ok, struct} = result
      assert struct.id == "123"
      assert struct.name == "test"
      assert struct.value == 42
      
      # This response has more keys matching AnotherTestComponent than TestComponent
      response = {:ok, %{"id" => "123", "type" => "test", "data" => %{}, "extra" => "ignored"}}
      result = test_convert_response(response, {:oneOf, [{:component, "TestComponent"}, {:component, "AnotherTestComponent"}]})
      
      assert match?({:ok, %AnotherTestComponent{}}, result)
      {:ok, struct} = result
      assert struct.id == "123"
      assert struct.type == "test"
      assert struct.data == %{}
    end

    test "handles oneOf when no components match" do
      response = {:ok, %{"foo" => "bar", "baz" => "qux"}}
      result = test_convert_response(response, {:oneOf, [{:component, "TestComponent"}, {:component, "AnotherTestComponent"}]})
      assert result == {:ok, %{"foo" => "bar", "baz" => "qux"}}
    end

    test "passes through error tuples unchanged" do
      response = {:error, "Something went wrong"}
      result = test_convert_response(response, {:component, "TestComponent"})
      assert result == {:error, "Something went wrong"}
    end

    test "handles nested data structures" do
      response = {:ok, %{
        "id" => "123",
        "name" => "test",
        "value" => %{"nested" => "data"},
        "array" => [%{"item" => 1}, %{"item" => 2}]
      }}
      
      result = test_convert_response(response, {:component, "TestComponent"})
      
      assert match?({:ok, %TestComponent{}}, result)
      {:ok, struct} = result
      assert struct.id == "123"
      assert struct.name == "test"
      assert is_map(struct.value)
      assert struct.value.nested == "data"
    end

    test "handles string keys by converting them to atoms" do
      response = {:ok, %{"id" => "123", "name" => "test"}}
      result = test_convert_response(response, {:component, "TestComponent"})
      
      assert match?({:ok, %TestComponent{}}, result)
      {:ok, struct} = result
      assert struct.id == "123"
      assert struct.name == "test"
      assert struct.value == nil
    end

    test "handles unknown response types by returning original response" do
      response = {:ok, %{"id" => "123", "name" => "test"}}
      result = test_convert_response(response, {:unknown_type, "something"})
      assert result == {:ok, %{"id" => "123", "name" => "test"}}
    end
  end
end