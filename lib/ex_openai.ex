defmodule ExOpenAI do
  @moduledoc """
  Provides API wrappers for OpenAI API
  See https://beta.openai.com/docs/api-reference/introduction for further info on REST endpoints
  """

  use Application

  alias ExOpenAI.Config

  def start(_type, _args) do
    children = [Config]
    opts = [strategy: :one_for_one, name: ExOpenAI.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def parse_property(%{"name" => name, "description" => desc, "type" => "array"}) do
    %{
      name: name,
      description: desc,
      type: "array"
    }
  end

  def parse_property(%{"name" => name, "description" => desc, "oneOf" => oneOf}) do
    # parse oneOf array into a list of schemas
    #    "oneOf" => [
    #      %{
    #        "default" => "",
    #        "example" => "I want to kill them.",
    #        "type" => "string"
    #      },
    #      %{
    #        "items" => %{
    #          "default" => "",
    #          "example" => "I want to kill them.",
    #          "type" => "string"
    #        },
    #        "type" => "array"
    #      }
    #    ],

    %{
      name: name,
      description: desc,
      type: "oneOf",
      oneOf:
        Enum.map(oneOf, fn item -> Map.put(parse_get_schema(item), :default, item["default"]) end)
    }
  end

  def parse_property(
        %{
          "name" => name,
          "type" => type
        } = args
      ) do
    %{
      type: type,
      name: name,
      # optional
      description: Map.get(args, "description", ""),
      # optional
      example: Map.get(args, "example", "")
    }
  end

  def parse_property(args) do
    IO.puts("Unknown property")
    IO.inspect(args)
  end

  @doc """
  Pattern 1:
  properties:
    object:
      type: string
    model:
      type: string
    data:
      type: array
      items:
        type: object
        properties:
          index:
            type: integer
          object:
            type: string
          embedding:
            type: array
            items:
              type: number
        required:
          - index
          - object
          - embedding

  Pattern 2:
  properties:
    model: *model_configuration
    input:
      description: Desc
      example: The quick brown fox jumped over the lazy dog
      oneOf:
        - type: string
          default: ''
          example: "This is a test."
        - type: array
          items:
            type: string
            default: ''
            example: "This is a test."
        - type: array
          minItems: 1
          items:
            type: integer
          example: [1212, 318, 257, 1332, 13]
        - type: array
          minItems: 1
          items:
            type: array
            minItems: 1
            items:
              type: integer
          example: "[[1212, 318, 257, 1332, 13]]"
    user: *end_user_param_configuration
  """
  def parse_properties(props) when is_list(props) do
    Enum.map(props, &parse_property(&1))
  end

  @doc """

  In yaml:
  ```
  CreateEmbeddingRequest:
      type: object
      additionalProperties: false
      properties:
        model: *model_configuration
        input:
          description: Desc
          example: The quick brown fox jumped over the lazy dog
          oneOf:
            - type: string
              default: ''
              example: "This is a test."
            - type: array
              items:
                type: string
                default: ''
                example: "This is a test."
            - type: array
              minItems: 1
              items:
                type: integer
              example: "[1212, 318, 257, 1332, 13]"
            - type: array
              minItems: 1
              items:
                type: array
                minItems: 1
                items:
                  type: integer
              example: "[[1212, 318, 257, 1332, 13]]"
        user: *end_user_param_configuration
      required:
        - model
        - input
  ```
  """
  def parse_component_schema(%{"properties" => props, "required" => required}) do
    # optional params go into kw list
    # required params go into arguments

    # turn required stuf into hashmap for quicker access and merge into actual properties
    required_map = required |> Enum.reduce(%{}, fn item, acc -> Map.put(acc, item, true) end)

    merged_props =
      props
      |> Enum.map(fn {key, val} ->
        case Map.has_key?(required_map, key) do
          is_required -> Map.put(val, "required", is_required) |> Map.put("name", key)
        end
      end)

    required_props = merged_props |> Enum.filter(&(Map.get(&1, "required") == true))
    optional_props = merged_props |> Enum.filter(&(Map.get(&1, "required") == false))

    %{
      required_props: parse_properties(required_props),
      optional_props: parse_properties(optional_props)
    }
  end

  def parse_component_schema(%{"properties" => props}),
    do: parse_component_schema(%{"properties" => props, "required" => []})

  @doc """
  Converts a GET field schema definition into a %{type: "string", example: "string"}-like map
  In yaml:
      type: string
      example:
        text-davinci-001
  """
  @spec parse_get_schema(map()) :: %{type: String.t(), example: String.t()}
  def parse_get_schema(%{"type" => type, "example" => example}) do
    %{type: type, example: example}
  end

  def parse_get_schema(%{"type" => _type} = args),
    do: parse_get_schema(Map.put(args, "example", ""))

  @doc """
  Parses the given body construct into a map
  In yaml:
  requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              $ref: '#/components/schemas/CreateFileRequest'
  """
  def parse_request_body(%{"required" => required, "content" => content}, component_mapping) do
    {content_type, rest} =
      content
      |> Map.to_list()
      |> List.first()

    # resolve the object ref to the actual component to get the schema
    ref =
      rest["schema"]["$ref"]
      |> String.replace_prefix("#/components/schemas/", "")
      |> Macro.underscore()

    case content_type do
      "application/json" ->
        %{
          required?: required,
          content_type: String.to_atom(content_type),
          # rest: rest,
          # ref: ref,
          request_schema: Map.get(component_mapping, ref)
        }

      # TODO: other types like multipart/form-data is not supported yet
      _ ->
        :unsupported_content_type
    end
  end

  def parse_request_body(nil, _) do
    nil
  end

  @doc """
  Parses a list of properties into usable function arguments
  Properties is a list of [%{"name" => "xxx", "in" => "xxx"}}], or im yaml
  parameters:
  - in: path
    name: model
    required: true
    schema:
      type: string
      example:
        text-davinci-001
    description:
      The ID of the model to use for this request
  """
  @spec parse_get_arguments(any()) :: %{
          name: String.t(),
          in: String.t(),
          type: String.t(),
          example: String.t(),
          required?: boolean()
        }
  def parse_get_arguments(%{"name" => name, "schema" => schema, "in" => inarg} = args) do
    Map.merge(
      %{name: name, in: inarg, required?: Map.get(args, "required", false)},
      parse_get_schema(schema)
    )
  end

  def parse_path(
        path,
        %{
          "post" =>
            %{
              "operationId" => id,
              "summary" => summary,
              "requestBody" => body,
              "responses" => responses,
              "x-oaiMeta" => %{"group" => group}
            } = args
        },
        component_mapping
      ) do
    %{
      endpoint: path,
      name: Macro.underscore(id),
      summary: summary,
      deprecated?: Map.has_key?(args, "deprecated"),
      arguments: Map.get(args, "parameters", []) |> Enum.map(&parse_get_arguments(&1)),
      method: :post,
      request_body: parse_request_body(body, component_mapping),
      group: group
    }
  end

  def parse_path(
        path,
        %{
          "post" =>
            %{
              "operationId" => id,
              "summary" => summary,
              "responses" => responses,
              "x-oaiMeta" => meta
            } = args
        },
        component_mapping
      ) do
    parse_path(path, %{"post" => Map.put(args, "requestBody", nil)}, component_mapping)
  end

  def parse_path(path, %{"post" => args}, component_mapping) do
    # IO.puts("unhandled")
    # IO.inspect(args)
    nil
  end

  def parse_path(path, %{"delete" => post}, component_mapping) do
  end

  @doc "parse GET functions and generate function definition"
  def(
    parse_path(
      path,
      %{
        "get" =>
          %{
            "operationId" => id,
            "summary" => summary,
            "responses" => responses,
            "x-oaiMeta" => %{"group" => group}
          } = args
      },
      component_mapping
    )
  ) do
    %{
      endpoint: path,
      name: Macro.underscore(id),
      summary: summary,
      deprecated?: Map.has_key?(args, "deprecated"),
      arguments: Map.get(args, "parameters", []) |> Enum.map(&parse_get_arguments(&1)),
      method: :get,
      group: group
    }
  end

  def get_documentation do
    {:ok, yml} =
      File.read!("docs.yaml")
      |> YamlElixir.read_from_string()

    component_mapping =
      yml["components"]["schemas"]
      |> Enum.reduce(%{}, fn {name, value}, acc ->
        Map.put(acc, Macro.underscore(name), parse_component_schema(value))
      end)

    yml["paths"]
    |> Enum.map(fn {path, field_data} -> parse_path(path, field_data, component_mapping) end)
    |> Enum.filter(&(!is_nil(&1)))
    # TODO: implement form-data
    |> Enum.filter(&Kernel.!=(Map.get(&1, :request_body, nil), :unsupported_content_type))
  end

  def type_to_spec("number"), do: quote(do: float())
  def type_to_spec("integer"), do: quote(do: integer())
  def type_to_spec("boolean"), do: quote(do: boolean())
  def type_to_spec("string"), do: quote(do: String.t())
  # TODO: handle these types here better
  def type_to_spec("array"), do: quote(do: list())
  def type_to_spec("object"), do: quote(do: map())
  def type_to_spec("oneOf"), do: quote(do: any())

  def type_to_spec(x) do
    IO.puts("unhandled: #{x}")
    quote(do: any())
  end

  def generate_get_function() do
  end
end

# Generate modules

ExOpenAI.get_documentation()
|> Enum.reduce(%{}, fn fx, acc ->
  Map.put(acc, fx.group, [fx | Map.get(acc, fx.group, [])])
end)
|> Enum.each(fn {modname, functions} ->
  # some-name -> ExOpenAI.SomeName
  modname =
    modname
    |> String.replace("-", "_")
    |> Macro.camelize()
    |> String.to_atom()
    |> (&Module.concat(ExOpenAI, &1)).()

  defmodule modname do
    functions
    |> Enum.each(fn fx ->
      %{
        name: name,
        summary: summary,
        arguments: args,
        endpoint: endpoint,
        deprecated?: deprecated,
        method: method
      } = fx

      name = String.to_atom(name)

      merged_required_args =
        case method do
          :post ->
            args ++
              if(is_nil(fx.request_body),
                do: [],
                else: fx.request_body.request_schema.required_props
              )

          :get ->
            args
        end

      required_args_docstring =
        Enum.map(merged_required_args, fn i ->
          s = "- `#{i.name}`"
          s = if Map.has_key?(i, :description), do: "#{s}: #{Map.get(i, :description)}", else: s

          s =
            if Map.get(i, :example, "") != "",
              do: "#{s}\n\n*Example*: `#{Map.get(i, :example)}`",
              else: s

          s
        end)
        |> Enum.join("\n\n")

      merged_optional_args =
        case method do
          :post ->
            Enum.filter(args, &(!Map.get(&1, :required?))) ++
              if(is_nil(fx.request_body),
                do: [],
                else: fx.request_body.request_schema.optional_props
              )

          :get ->
            Enum.filter(args, &(!Map.get(&1, :required?)))
        end

      optional_args_docstring =
        Enum.map(merged_optional_args, fn i ->
          s = "- `#{i.name}`"
          s = if Map.has_key?(i, :description), do: "#{s}: #{Map.get(i, :description)}", else: s

          s =
            if Map.get(i, :example, "") != "",
              do: "#{s}\n\n*Example*: `#{Map.get(i, :example)}`",
              else: s

          s
        end)
        |> Enum.join("\n\n")

      # convert non-optional args into [arg1, arg2, arg3] representation
      arg_names =
        merged_required_args
        |> Enum.map(&(Map.get(&1, :name) |> String.to_atom() |> Macro.var(nil)))

      # convert non-optional args into spec definition [String.t(), String.t(), etc.] representation
      spec =
        merged_required_args
        |> Enum.map(fn item -> quote do: unquote(ExOpenAI.type_to_spec(item.type)) end)

      # convert optional args into keyword list
      optional_args =
        merged_optional_args
        |> Enum.reduce(nil, fn item, acc ->
          name = item.name
          type = item.type

          case acc do
            nil ->
              quote do: {unquote(String.to_atom(name)), unquote(ExOpenAI.type_to_spec(type))}

            val ->
              quote do:
                      unquote(val)
                      | {unquote(String.to_atom(name)), unquote(ExOpenAI.type_to_spec(type))}
          end
        end)

      @doc """
      Endpoint `#{endpoint}`

      #{summary}

      ---

      ### Required Arguments: 

      #{required_args_docstring}


      ### Optional Arguments: 

      #{optional_args_docstring}
      """
      if deprecated, do: @deprecated("Deprecated by OpenAI")

      @spec unquote(name)(unquote_splicing(spec), unquote([optional_args])) ::
              {:ok, any()} | {:error, any()}
      def unquote(name)(unquote_splicing(arg_names), opts \\ []) do
        # store binding so we can't access args of the function later
        binding = binding()

        required_arguments = unquote(Macro.escape(merged_required_args))
        optional_arguments = unquote(Macro.escape(merged_optional_args))
        arguments = required_arguments ++ optional_arguments
        url = "#{unquote(endpoint)}"
        method = unquote(method)

        # merge all passed args together, so opts + passed
        all_passed_args = Keyword.merge(binding, opts) |> Keyword.drop([:opts])

        # replace all args in the URL that are specified as 'path'
        # for example: /model/{model_id} -> /model/123
        url =
          arguments
          |> Enum.filter(&Kernel.==(Map.get(&1, :in, ""), "path"))
          |> Enum.reduce(
            url,
            &String.replace(
              &2,
              "{#{&1.name}}",
              Keyword.get(all_passed_args, String.to_atom(&1.name))
            )
          )
          # iterate over all other arguments marked with in: "query", and append them to the query
          # for example /model/123?foo=bar
          |> URI.parse()
          |> URI.append_query(
            Enum.filter(arguments, &Kernel.==(Map.get(&1, :in, ""), "query"))
            |> Enum.reduce(%{}, fn item, acc ->
              Map.put(acc, item.name, Keyword.get(all_passed_args, String.to_atom(item.name)))
            end)
            |> URI.encode_query()
          )
          |> URI.to_string()

        # construct body with the remaining args

        body_params =
          arguments
          # filter by all the rest, so neither query nor path
          |> Enum.filter(&Kernel.==(Map.get(&1, :in, ""), ""))
          |> Enum.filter(&(!is_nil(Keyword.get(all_passed_args, String.to_atom(&1.name)))))
          |> Enum.reduce(
            [],
            &Keyword.merge(&2, [
              {
                String.to_atom(&1.name),
                Keyword.get(all_passed_args, String.to_atom(&1.name))
              }
            ])
          )

        # construct body
        case method do
          :post ->
            ExOpenAI.Client.api_post(url, body_params, opts)

          :get ->
            ExOpenAI.Client.api_get(url, opts)
        end
      end

      # Module.create(Hoge1, c, Macro.Env.location(__ENV__))
    end)
  end
end)
