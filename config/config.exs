import Config

if config_env() == :test do
  config :exvcr,
    filter_request_headers: [
      "OpenAI-Organization",
      "Openai-Organization",
      "openai-organization",
      "Authorization",
      "Set-Cookie"
    ]
end
