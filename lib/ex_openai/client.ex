defmodule ExOpenAI.Client do
  @moduledoc false
  use HTTPoison.Base
  alias ExOpenAI.Config

  def add_base_url(url, base_url), do: Config.api_url(base_url) <> url

  def process_response_body(body) do
    case Jason.decode(body) do
      {:ok, decoded_json} -> {:ok, decoded_json}
      # audio/speech endpoint returns binary data, so leave as is
      _ -> {:ok, body}
    end
  end

  def handle_response(httpoison_response) do
    case httpoison_response do
      {:ok, %HTTPoison.Response{status_code: 200, body: {:ok, body}}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{body: {:ok, body}}} ->
        {:error, body}

      {:ok, %HTTPoison.AsyncResponse{id: ref}} ->
        {:ok, ref}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @spec add_bearer_header(list(), String.t() | nil) :: list()
  def add_bearer_header(headers, api_key \\ nil) do
    if is_nil(api_key) do
      [{"Authorization", "Bearer #{Config.api_key()}"} | headers]
    else
      [{"Authorization", "Bearer #{api_key}"} | headers]
    end
  end

  @spec add_organization_header(list(), String.t() | nil) :: list()
  def add_organization_header(headers, org_key \\ nil) do
    if is_nil(org_key) do
      if Config.org_key() do
        [{"OpenAI-Organization", Config.org_key()} | headers]
      else
        headers
      end
    else
      [{"OpenAI-Organization", org_key} | headers]
    end
  end

  @spec add_json_request_headers(list()) :: list()
  def add_json_request_headers(headers) do
    [{"Content-type", "application/json"} | headers]
  end

  @spec add_multipart_request_headers(list()) :: list()
  def add_multipart_request_headers(headers) do
    [{"Content-type", "multipart/form-data"} | headers]
  end

  def request_options(), do: Config.http_options()

  def default_headers(), do: Config.http_headers()

  def stream_options(request_options, convert_response) do
    with {:ok, stream_val} <- Keyword.fetch(request_options, :stream),
         {:ok, stream_to} when is_pid(stream_to) or is_function(stream_to) <-
           Keyword.fetch(request_options, :stream_to),
         true <- stream_val do
      # spawn a new StreamingClient and tell it to forward data to `stream_to`
      {:ok, sse_client_pid} = ExOpenAI.StreamingClient.start_link(stream_to, convert_response)
      [stream_to: sse_client_pid]
    else
      _ ->
        [stream_to: nil]
    end
  end

  def api_get(url, request_options \\ [], convert_response) do
    request_options = Keyword.merge(request_options(), request_options)
    stream_options = stream_options(request_options, convert_response)

    request_options =
      Map.merge(Enum.into(request_options, %{}), Enum.into(stream_options, %{}))
      |> Map.to_list()

    request_options_map = Enum.into(request_options, %{})

    headers =
      default_headers()
      |> add_json_request_headers()
      |> add_organization_header(Map.get(request_options_map, :openai_organization_key, nil))
      |> add_bearer_header(Map.get(request_options_map, :openai_api_key, nil))

    base_url = Map.get(request_options_map, :base_url)

    url
    |> add_base_url(base_url)
    |> get(headers, request_options)
    |> handle_response()
    |> convert_response.()
  end

  defp strip_params(params) do
    params
    # remove stream_to from params as PID messes with Jason
    |> Map.drop([:stream_to, :openai_organization_key, :openai_api_key])
  end

  def api_post(url, params \\ [], request_options \\ [], convert_response) do
    body =
      params
      |> Enum.into(%{})
      |> strip_params()
      |> Jason.encode()
      |> elem(1)

    request_options = Keyword.merge(request_options(), request_options)
    stream_options = stream_options(request_options, convert_response)

    request_options =
      Map.merge(Enum.into(request_options, %{}), Enum.into(stream_options, %{}))
      |> Map.to_list()

    request_options_map = Enum.into(request_options, %{})

    headers =
      default_headers()
      |> add_json_request_headers()
      |> add_organization_header(Map.get(request_options_map, :openai_organization_key, nil))
      |> add_bearer_header(Map.get(request_options_map, :openai_api_key, nil))

    base_url = Map.get(request_options_map, :base_url)

    url
    |> add_base_url(base_url)
    |> post(body, headers, request_options)
    |> handle_response()
    |> convert_response.()
  end

  def api_delete(url, request_options \\ [], convert_response) do
    request_options = Keyword.merge(request_options(), request_options)
    stream_options = stream_options(request_options, convert_response)

    request_options =
      Map.merge(Enum.into(request_options, %{}), Enum.into(stream_options, %{}))
      |> Map.to_list()

    request_options_map = Enum.into(request_options, %{})

    headers =
      default_headers()
      |> add_json_request_headers()
      |> add_organization_header(Map.get(request_options_map, :openai_organization_key, nil))
      |> add_bearer_header(Map.get(request_options_map, :openai_api_key, nil))

    base_url = Map.get(request_options_map, :base_url)

    url
    |> add_base_url(base_url)
    |> delete(headers, request_options)
    |> handle_response()
    |> convert_response.()
  end

  defp multipart_param({name, {filename, content}}) do
    with strname <- Atom.to_string(name) do
      cond do
        # Strings can be valid bitstreams and bitstreams are valid binaries
        # Using String.valid? for comparison instead
        is_bitstring(content) and not String.valid?(content) ->
          {"file", content, {"form-data", [name: strname, filename: "#{filename}"]}, []}

        true ->
          {strname, content}
      end
    end
  end

  defp multipart_param({name, content}) do
    multipart_param({name, {name, content}})
  end

  def api_multipart_post(url, params \\ [], request_options \\ [], convert_response) do
    request_options = Keyword.merge(request_options(), request_options)
    stream_options = stream_options(request_options, convert_response)

    request_options =
      Map.merge(Enum.into(request_options, %{}), Enum.into(stream_options, %{}))
      |> Map.to_list()

    request_options_map = Enum.into(request_options, %{})

    multipart_body =
      {:multipart,
       params
       |> Enum.into(%{})
       |> strip_params()
       |> Map.to_list()
       |> Enum.map(&multipart_param/1)}

    headers =
      default_headers()
      |> add_multipart_request_headers()
      |> add_organization_header(Map.get(request_options_map, :openai_organization_key, nil))
      |> add_bearer_header(Map.get(request_options_map, :openai_api_key, nil))

    base_url = Map.get(request_options_map, :base_url)

    url
    |> add_base_url(base_url)
    |> post(multipart_body, headers, request_options)
    |> handle_response()
    |> convert_response.()
  end

  @callback api_call(
              method :: atom(),
              url :: String.t(),
              params :: Keyword.t(),
              request_content_type :: Keyword.t(),
              request_options :: Keyword.t(),
              convert_response :: any()
            ) :: {:ok, res :: term()} | {:error, res :: term()}
  def api_call(:get, url, _params, _request_content_type, request_options, convert_response),
    do: api_get(url, request_options, convert_response)

  def api_call(:post, url, params, :"multipart/form-data", request_options, convert_response),
    do: api_multipart_post(url, params, request_options, convert_response)

  def api_call(:post, url, params, _request_content_type, request_options, convert_response),
    do: api_post(url, params, request_options, convert_response)

  def api_call(:delete, url, _params, _request_content_type, request_options, convert_response),
    do: api_delete(url, request_options, convert_response)
end
