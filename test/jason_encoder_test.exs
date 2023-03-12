defmodule ExOpenAI.JasonEncoderTest do
  use ExUnit.Case, async: true

  defp encode_and_return(val) do
    {:ok, res} = Jason.encode(val)
    res
  end

  # list models is one of those endpoints that returns a bunch of stuff that's not included
  # in the official openapi docs, causing unknown atoms to be created
  test "atoms as strings" do
    assert encode_and_return(:foo) == "\"foo\""
    assert encode_and_return([:one, :two, "three"]) == "[\"one\",\"two\",\"three\"]"
  end

  test "drop nil" do
    assert encode_and_return(%ExOpenAI.Components.ChatCompletionRequestMessage{
             content: "abc",
             role: :assistant,
             name: nil
           }) == "{\"content\":\"abc\",\"role\":\"assistant\"}"
  end

  test "normal map" do
    assert encode_and_return(%{:foo => "bar", "bar" => :foo}) ==
             "{\"foo\":\"bar\",\"bar\":\"foo\"}"
  end

  test "list of structs" do
    msgs = [
      %ExOpenAI.Components.ChatCompletionRequestMessage{
        role: :user,
        content: "Hello!"
      },
      %ExOpenAI.Components.ChatCompletionRequestMessage{
        role: :assistant,
        content: "What's up?"
      },
      %ExOpenAI.Components.ChatCompletionRequestMessage{
        role: :user,
        content: "What ist the color of the sky?"
      }
    ]

    assert encode_and_return(msgs) ==
             "[{\"content\":\"Hello!\",\"role\":\"user\"},{\"content\":\"What's up?\",\"role\":\"assistant\"},{\"content\":\"What ist the color of the sky?\",\"role\":\"user\"}]"
  end
end
