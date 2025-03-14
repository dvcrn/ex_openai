defmodule ExOpenAI.ResponsesTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup do
    ExVCR.Config.cassette_library_dir("./test/fixture/vcr_cassettes")
    :ok
  end

  test "responses completion" do
    recorder =
      ExVCR.Mock.start_cassette("responses_basic_usage",
        match_requests_on: [:query, :request_body]
      )

    {:ok, res} = ExOpenAI.Responses.create_response("tell me a joke", "gpt-4o-mini")

    assert res.model == "gpt-4o-mini-2024-07-18"
    assert res.object == "response"
    assert res.status == "completed"

    output = List.first(res.output)
    assert output.type == "message"
    assert output.role == "assistant"

    {:ok, get_res} = ExOpenAI.Responses.get_response(res.id)

    # should be the same because we haven't done anything new yet
    assert get_res.id == res.id
    ExVCR.Mock.stop_cassette(recorder)

    r =
      ExVCR.Mock.start_cassette("responses_basic_usage_second_message",
        match_requests_on: [:query, :request_body]
      )

    # responses API is stateful so it will have context of the previus message

    {:ok, another_one} =
      ExOpenAI.Responses.create_response(
        "Please tell me what I asked you to do in my previous message ok??",
        "gpt-4o-mini",
        previous_response_id: res.id
      )

    assert another_one.id != get_res.id

    {:ok, get_res} = ExOpenAI.Responses.get_response(another_one.id)

    first = List.first(get_res.output)

    assert List.first(first.content).text ==
             "You asked me to tell you a joke. Would you like to hear another one?"

    ExVCR.Mock.stop_cassette(r)
  end
end
