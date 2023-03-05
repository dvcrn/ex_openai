defmodule Mix.Tasks.UpdateDocs do
  @moduledoc """
  Updates OpenAI API documentation files
  """

  use Mix.Task

  @impl Mix.Task
  def run(_) do
    System.cmd("curl", [
      "https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml",
      ">",
      "docs.yaml"
    ])
  end
end
