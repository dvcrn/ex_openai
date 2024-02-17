defmodule ExOpenAI.TextToSpeechTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup do
    ExVCR.Config.cassette_library_dir("./test/fixture/vcr_cassettes")
    :ok
  end

  test "audio text-to-speech" do
    use_cassette "audio_text_to_speech" do
      {:ok, res} =
        ExOpenAI.Audio.create_speech("Hello, hello, hello, just a test.", :"tts-1-hd", :shimmer)

      assert res != nil
      assert byte_size(res) == 37920
    end
  end
end
