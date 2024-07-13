defmodule ExOpenAI.AssistantTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup do
    ExVCR.Config.cassette_library_dir("./test/fixture/vcr_cassettes")
    :ok
  end

  test "non-streaming assistant" do
    use_cassette "math_assistant" do
      {:ok, assistant} =
        ExOpenAI.Assistants.create_assistant(:"gpt-4o",
          name: "Math Teacher",
          instruction:
            "You are a personal math tutor. Write and run code to answer math questions.",
          tools: [%{type: "code_interpreter"}]
        )

      {:ok, thread} = ExOpenAI.Threads.create_thread()

      {:ok, _msg} =
        ExOpenAI.Threads.create_message(
          thread.id,
          "I need to solve the equation `3x + 11 = 14`. Can you help me?",
          "user"
        )

      {:ok, _run} =
        ExOpenAI.Threads.create_run(
          thread.id,
          assistant.id
        )

      # sleep for 5 seconds to generate the cassette
      # :timer.sleep(5000)

      {:ok, messages} = ExOpenAI.Threads.list_messages(thread.id)
      assert Enum.count(messages.data) == 2
    end
  end
end
