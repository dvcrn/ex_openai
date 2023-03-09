defmodule ExOpenAI.ModelsTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup do
    ExVCR.Config.cassette_library_dir("./test/fixture/vcr_cassettes")
    :ok
  end

  # list models is one of those endpoints that returns a bunch of stuff that's not included
  # in the official openapi docs, causing unknown atoms to be created
  test "list models" do
    use_cassette "list_models" do
      {:ok, res} = ExOpenAI.Models.list_models()
      assert Enum.count(res.data) == 69
    end
  end
end
