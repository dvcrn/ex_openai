# Configuration Options

ExOpenAI provides several configuration options to customize its behavior. This document explains all available configuration options and how to use them effectively.

## Basic Configuration

The most basic configuration requires setting your OpenAI API key:

```elixir
# In config/config.exs
config :ex_openai,
  api_key: System.get_env("OPENAI_API_KEY")
```

## Complete Configuration Options

Here's a complete list of all configuration options:

```elixir
config :ex_openai,
  # Required: Your OpenAI API key
  api_key: System.get_env("OPENAI_API_KEY"),
  
  # Optional: Your OpenAI organization ID
  organization_key: System.get_env("OPENAI_ORGANIZATION_KEY"),
  
  # Optional: Base URL for API requests (default: https://api.openai.com/v1)
  base_url: System.get_env("OPENAI_API_URL"),
  
  # Optional: HTTP options passed to HTTPoison
  http_options: [recv_timeout: 50_000],
  
  # Optional: Default request headers
  http_headers: [
    {"OpenAI-Beta", "assistants=v2"}
  ],
  
  # Optional: HTTP client module (default: ExOpenAI.Client)
  http_client: ExOpenAI.Client
```

## Configuration Options Explained

### API Key

The `api_key` is required for authenticating with the OpenAI API. You can find your API key in the [OpenAI dashboard](https://platform.openai.com/account/api-keys).

```elixir
config :ex_openai,
  api_key: System.get_env("OPENAI_API_KEY")
```

### Organization Key

If you belong to multiple organizations, you can specify which organization to use with the `organization_key`:

```elixir
config :ex_openai,
  organization_key: System.get_env("OPENAI_ORGANIZATION_KEY")
```

### Base URL

By default, ExOpenAI uses `https://api.openai.com/v1` as the base URL. You can override this if you're using a proxy or a different endpoint:

```elixir
config :ex_openai,
  base_url: "https://your-proxy.example.com/v1"
```

### HTTP Options

You can customize the HTTP client behavior by passing options to HTTPoison:

```elixir
config :ex_openai,
  http_options: [
    recv_timeout: 50_000,  # 50 seconds timeout
    ssl: [versions: [:"tlsv1.2"]],
    proxy: "http://proxy.example.com:8080"
  ]
```

Common HTTP options include:

- `recv_timeout`: Maximum time to wait for a response (milliseconds)
- `timeout`: Connection timeout (milliseconds)
- `ssl`: SSL options
- `proxy`: Proxy server configuration
- `hackney`: Options passed directly to hackney

### HTTP Headers

You can set default headers for all requests:

```elixir
config :ex_openai,
  http_headers: [
    {"OpenAI-Beta", "assistants=v2"},
    {"User-Agent", "MyApp/1.0"}
  ]
```

### HTTP Client

For testing or custom HTTP handling, you can specify a different HTTP client module:

```elixir
config :ex_openai,
  http_client: MyCustomClient
```

The custom client must implement the same interface as `ExOpenAI.Client`.

## Per-Request Configuration

You can override configuration options on a per-request basis by passing them as options to API calls:

```elixir
ExOpenAI.Models.list_models(
  openai_api_key: "different-api-key",
  openai_organization_key: "different-org",
  base_url: "https://different-api-endpoint.com/v1"
)
```

This is useful for applications that need to switch between different API keys or organizations.

## Environment Variables

ExOpenAI respects the following environment variables:

- `OPENAI_API_KEY`: Your OpenAI API key
- `OPENAI_ORGANIZATION_KEY`: Your OpenAI organization ID
- `OPENAI_API_URL` or `OPENAI_API_BASE`: Base URL for API requests

These can be set in your environment or through a `.env` file with a package like [dotenvy](https://hex.pm/packages/dotenvy).

## Testing Configuration

For testing, you might want to use a mock client:

```elixir
# In config/test.exs
config :ex_openai,
  http_client: MyApp.MockOpenAIClient
```

Then implement your mock client:

```elixir
defmodule MyApp.MockOpenAIClient do
  def request(method, url, body, headers, options) do
    # Return mock responses based on the request
    case {method, url} do
      {:get, "/models"} ->
        {:ok, %{status_code: 200, body: ~s({"data": [{"id": "gpt-4", "object": "model"}]})}}
      _ ->
        {:error, %{reason: "Not implemented in mock"}}
    end
  end
end
```

## Configuration Best Practices

1. **Use environment variables** for sensitive information like API keys
2. **Set reasonable timeouts** based on your application's needs
3. **Consider using different configurations** for development, testing, and production
4. **Use per-request overrides** sparingly, for special cases only
5. **Keep your API keys secure** and rotate them regularly