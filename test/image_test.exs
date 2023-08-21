defmodule ExOpenAI.ImageTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup do
    ExVCR.Config.cassette_library_dir("./test/fixture/vcr_cassettes")
    :ok
  end

  test "image variation" do
    use_cassette "image_variation" do
      duck = File.read!("#{__DIR__}/testdata/duck.png")

      {:ok, res} = ExOpenAI.Images.create_image_variation(duck)

      assert Enum.count(res.data) == 1
      assert List.first(res.data) |> Map.get(:url) |> is_binary()
    end
  end

  test "image variation with parameters" do
    use_cassette "image_variation_b64" do
      duck = File.read!("#{__DIR__}/testdata/duck.png")

      {:ok, res} = ExOpenAI.Images.create_image_variation(duck, response_format: "b64_json")

      assert Enum.count(res.data) == 1
      assert List.first(res.data) |> Map.get(:b64_json) |> is_binary()
    end
  end

  test "image variation with filename tuple" do
    use_cassette "image_variation_tuple" do
      duck = File.read!("#{__DIR__}/testdata/duck.png")

      {:ok, res} = ExOpenAI.Images.create_image_variation({"duck.png", duck})

      assert Enum.count(res.data) == 1
      assert List.first(res.data) |> Map.get(:url) |> is_binary()
    end
  end
end
