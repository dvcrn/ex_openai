defmodule ExOpenAI.Client do
  @moduledoc false
  alias ExOpenAI.Config
  use HTTPoison.Base

  def process_url(url), do: Config.api_url() <> url

  def process_response_body(body), do: Jason.decode(body)

  def handle_response(httpoison_response) do
    case httpoison_response do
      {:ok, %HTTPoison.Response{status_code: 200, body: {:ok, body}}} ->
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

  def stream_options(request_options, convert_response) do
    with {:ok, stream_val} <- Keyword.fetch(request_options, :stream),
         {:ok, stream_to} when is_pid(stream_to) <- Keyword.fetch(request_options, :stream_to),
         true <- stream_val do
      {:ok, sse_client_pid} = ExOpenAI.StreamingClient.start_link(stream_to, convert_response)
      [stream_to: sse_client_pid]
    else
      _ ->
        []
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
      []
      |> add_json_request_headers()
      |> add_organization_header(Map.get(request_options_map, :openai_organization_key, nil))
      |> add_bearer_header(Map.get(request_options_map, :openai_api_key, nil))

    url
    |> get(headers, request_options)
    |> handle_response()
    |> convert_response.()
  end

  def api_post(url, params \\ [], request_options \\ [], convert_response) do
    body =
      params
      |> Enum.into(%{})
      # remove stream_to from params as PID messes with Jason
      |> Map.delete(:stream_to)
      |> Jason.encode()
      |> elem(1)

    request_options = Keyword.merge(request_options(), request_options)
    stream_options = stream_options(request_options, convert_response)

    request_options =
      Map.merge(Enum.into(request_options, %{}), Enum.into(stream_options, %{}))
      |> Map.to_list()

    request_options_map = Enum.into(request_options, %{})

    headers =
      []
      |> add_json_request_headers()
      |> add_organization_header(Map.get(request_options_map, :openai_organization_key, nil))
      |> add_bearer_header(Map.get(request_options_map, :openai_api_key, nil))

    url
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
      []
      |> add_json_request_headers()
      |> add_organization_header(Map.get(request_options_map, :openai_organization_key, nil))
      |> add_bearer_header(Map.get(request_options_map, :openai_api_key, nil))

    url
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
       |> Enum.map(&multipart_param/1)}

    headers =
      []
      |> add_multipart_request_headers()
      |> add_organization_header(Map.get(request_options_map, :openai_organization_key, nil))
      |> add_bearer_header(Map.get(request_options_map, :openai_api_key, nil))

    url
    |> post(multipart_body, headers, request_options)
    |> handle_response()
    |> convert_response.()
  end

  def api_call(:get, url, _params, _request_content_type, request_options, convert_response),
    do: api_get(url, request_options, convert_response)

  def api_call(:post, url, params, :"multipart/form-data", request_options, convert_response),
    do: api_multipart_post(url, params, request_options, convert_response)

  def api_call(:post, url, params, _request_content_type, request_options, convert_response),
    do: api_post(url, params, request_options, convert_response)

  def api_call(:delete, url, _params, _request_content_type, request_options, convert_response),
    do: api_delete(url, request_options, convert_response)
end
