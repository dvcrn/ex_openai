defmodule ExOpenAI.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_openai,
      version: "1.5.0",
      elixir: "~> 1.13",
      description: description(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "ex_openai.ex",
      source_url: "https://github.com/dvcrn/ex_openai",
      preferred_cli_env: [
        vcr: :test,
        "vcr.delete": :test,
        "vcr.check": :test,
        "vcr.show": :test
      ],
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ExOpenAI, []},
      extra_applications: [:httpoison, :jason, :logger, :yaml_elixir]
    ]
  end

  defp description do
    """
    Auto-generated Elixir SDK for OpenAI APIs with proper typespec and @docs support
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      exclude_patterns: ["./config/*"],
      links: %{
        "GitHub" => "https://github.com/dvcrn/ex_openai"
      },
      maintainers: [
        "dvcrn"
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:mock, "~> 0.3.6", only: :test},
      {:httpoison, "~> 2.1.0"},
      {:mix_test_watch, "~> 1.0", only: :test},
      {:ex_doc, ">= 0.19.2", only: :dev},
      {:exvcr, "~> 0.14.4", only: :test},
      {:exjsx, "~> 4.0", only: :test},
      {:yaml_elixir, "~> 2.9"},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end
end
