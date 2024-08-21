defmodule ExOpenAI.ClientTest do
  use ExUnit.Case
  alias ExOpenAI.Client
  alias ExOpenAI.Config

  describe "api_url/1" do
    test "returns default URL when no override is provided" do
      assert Config.api_url() == "https://api.openai.com/v1"
    end

    test "returns overridden URL when provided" do
      override_url = "https://custom-api.example.com/v1"
      assert Config.api_url(override_url) == override_url
    end
  end

  describe "add_base_url/2" do
    test "adds base URL" do
      url = "/chat/completions"
      base_url = "https://api.openai.com/v1"
      assert Client.add_base_url(url, base_url) == "https://api.openai.com/v1/chat/completions"
    end

    test "uses custom base URL when provided" do
      url = "/chat/completions"
      base_url = "https://custom-api.example.com/v1"
      assert Client.add_base_url(url, base_url) == "https://custom-api.example.com/v1/chat/completions"
    end
  end
end
