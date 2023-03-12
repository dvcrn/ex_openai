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

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def bearer(), do: {"Authorization", "Bearer #{Config.api_key()}"}

  def add_organization_header(headers) do
    if Config.org_key() do
      [{"OpenAI-Organization", Config.org_key()} | headers]
    else
      headers
    end
  end

  def base_headers do
    [bearer()]
    |> add_organization_header()
  end

  def json_request_headers() do
    [{"Content-type", "application/json"} | base_headers()]
  end

  def multipart_request_headers() do
    [{"Content-type", "multipart/form-data"} | base_headers()]
  end

  def request_options(), do: Config.http_options()

  def api_get(url, request_options \\ []) do
    request_options = Keyword.merge(request_options(), request_options)

    url
    |> get(json_request_headers(), request_options)
    |> handle_response()
  end

  def api_post(url, params \\ [], request_options \\ []) do
    body =
      params
      |> Enum.into(%{})
      |> Jason.encode([])
      |> elem(1)

    request_options = Keyword.merge(request_options(), request_options)

    url
    |> post(body, json_request_headers(), request_options)
    |> handle_response()
  end

  def api_delete(url, request_options \\ []) do
    request_options = Keyword.merge(request_options(), request_options)

    url
    |> delete(json_request_headers(), request_options)
    |> handle_response()
  end

  defp multipart_param({name, content}) do
    with strname <- Atom.to_string(name) do
      cond do
        # Strings can be valid bitstreams and bitstreams are valid binaries
        # Using String.valid? for comparison instead
        is_bitstring(content) and not String.valid?(content) ->
          {"file", content, {"form-data", [name: strname, filename: "#{name}"]}, []}

        true ->
          {strname, content}
      end
    end
  end

  def api_multipart_post(url, params \\ [], request_options \\ []) do
    request_options = Keyword.merge(request_options(), request_options)

    multipart_body =
      {:multipart,
       params
       |> Enum.map(&multipart_param/1)}

    url
    |> post(multipart_body, multipart_request_headers(), request_options)
    |> handle_response()
  end

  def api_call(:get, url, _params, _request_content_type, request_options),
    do: api_get(url, request_options)

  def api_call(:post, url, params, :"multipart/form-data", request_options),
    do: api_multipart_post(url, params, request_options)

  def api_call(:post, url, params, _request_content_type, request_options),
    do: api_post(url, params, request_options)

  def api_call(:delete, url, _params, _request_content_type, request_options),
    do: api_delete(url, request_options)

  def request_headers do
    [
      bearer(),
      {"Content-type", "application/json"}
    ]
    |> add_organization_header()
  end
end
