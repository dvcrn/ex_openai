defmodule ExOpenAI.CompletionTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup do
    ExVCR.Config.cassette_library_dir("./test/fixture/vcr_cassettes")
    :ok
  end

  test "basic completion" do
    use_cassette "completion_basic_prompt" do
      {:ok, res} =
        ExOpenAI.Completions.create_completion(
          "text-davinci-003",
          prompt: "The apple is",
          temperature: 0.28,
          max_tokens: 100
        )

      assert Enum.count(res.choices) == 1

      assert List.first(res.choices) == %{
               finish_reason: "stop",
               index: 0,
               logprobs: nil,
               text:
                 " red\n\nThe apple is indeed red. Apples can come in a variety of colors, including red, green, yellow, and even pink."
             }
    end
  end
end
