defmodule ExOpenAI.PassApiKeyCredentialsTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup do
    ExVCR.Config.cassette_library_dir("./test/fixture/vcr_cassettes")
    :ok
  end

  # list models is one of those endpoints that returns a bunch of stuff that's not included
  # in the official openapi docs, causing unknown atoms to be created
  test "list models with custom api key" do
    use_cassette "list_models_custom_key" do
      {:error, res} =
        ExOpenAI.Models.list_models(openai_api_key: "abc", openai_organization_key: "def")

      assert res["error"]["code"] == "invalid_api_key"
    end
  end

  test "list models with env variable api key" do
    use_cassette "list_models_custom_key_env" do
      Application.put_env(:ex_openai, :api_key, "abc_from_env")
      Application.put_env(:ex_openai, :organization_key, "def_from_envxxxxx")

      {:error, res} = ExOpenAI.Models.list_models()
      assert res["error"]["code"] == "invalid_api_key"
    end
  end
end
