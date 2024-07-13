defmodule ExOpenAI.AudioTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup do
    ExVCR.Config.cassette_library_dir("./test/fixture/vcr_cassettes")
    :ok
  end

  test "audio transcription" do
    use_cassette "audio_transcription" do
      audio = File.read!("#{__DIR__}/testdata/audio.wav")

      {:ok, res} = ExOpenAI.Audio.create_transcription({"audio.wav", audio}, "whisper-1")

      assert res.text == "Hello, hello, hello, just a test."
    end
  end
end
