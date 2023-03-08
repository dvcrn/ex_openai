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

    # force allocate all possible keys / atoms that are within all available components
    # this allows us to use String.to_existing_atom without having to worry that those
    # atoms aren't allocated yet
    with {:ok, mods} <- :application.get_key(:ex_openai, :modules) do
      mods
      |> Enum.filter(&(&1 |> Module.split() |> Enum.at(1) == "Components"))
      |> Enum.map(& &1.get_ast)
    end

    Supervisor.start_link(children, opts)
  end

  defp parse_type(
         %{
           "type" => "object",
           "properties" => properties
         } = args
       ) do
    parsed_obj =
      properties
      |> Enum.map(fn {name, obj} ->
        case obj do
          %{"type" => type} ->
            {name, type}

          %{"$ref" => ref} ->
            {name, {:component, String.replace(ref, "#/components/schemas/", "")}}
        end
      end)
      |> Enum.into(%{})

    parsed_obj
  end

  defp parse_type(
         %{
           "type" => "array",
           "items" => items
         } = args
       ) do
    type =
      case items do
        # on nested array, recurse deeper
        %{"type" => "array", "items" => nested} ->
          {:array, parse_type(nested)}

        %{"type" => "object"} ->
          {:object, parse_type(items)}

        %{"type" => type} ->
          parse_type(items)

        %{"$ref" => ref} ->
          {:component, String.replace(ref, "#/components/schemas/", "")}

        %{} ->
          :object

        x ->
          IO.puts("invalid type:")
          IO.inspect(x)
      end
  end

  defp parse_type(%{"type" => type}), do: type

  defp parse_property(
         %{
           "type" => "array",
           "items" => items
         } = args
       ) do
    parse_property(Map.put(args, "type", {:array, parse_type(args)}))
  end

  defp parse_property(%{"name" => name, "description" => desc, "oneOf" => oneOf}) do
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

  defp parse_property(
         %{
           "type" => "object",
           "properties" => properties
         } = args
       ) do
    parse_property(Map.put(args, "type", {:object, parse_type(args)}))
  end

  defp parse_property(
         %{
           "type" => type,
           "name" => name
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

  defp parse_property(args) do
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
  defp parse_properties(props) when is_list(props) do
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
  defp parse_component_schema(%{"properties" => props, "required" => required}) do
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

  defp parse_component_schema(%{"properties" => props}),
    do: parse_component_schema(%{"properties" => props, "required" => []})

  @doc """
  Converts a GET field schema definition into a %{type: "string", example: "string"}-like map
  In yaml:
      type: string
      example:
        text-davinci-001
  """
  @spec parse_get_schema(map()) :: %{type: String.t(), example: String.t()}
  defp parse_get_schema(%{"type" => type, "example" => example}) do
    %{type: type, example: example}
  end

  defp parse_get_schema(%{"type" => _type} = args),
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
  defp parse_request_body(%{"required" => required, "content" => content}, component_mapping) do
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

  defp parse_request_body(nil, _) do
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
  defp parse_get_arguments(%{"name" => name, "schema" => schema, "in" => inarg} = args) do
    Map.merge(
      %{name: name, in: inarg, required?: Map.get(args, "required", false)},
      parse_get_schema(schema)
    )
  end

  @doc """
  Extracts the component name from the response schema, for example:
  %{
  "200" => %{
    "content" => %{
      "application/json" => %{
        "schema" => %{"$ref" => "#/components/schemas/ListEnginesResponse"}
      }
    },
    "description" => "OK"
  }
  }

  """
  defp extract_response_type(%{"200" => %{"content" => content}}) do
    case content
         # [["application/json", %{}]]
         |> Map.to_list()
         # ["application/json", %{}]
         |> List.first()
         # %{}
         |> Kernel.elem(1)
         |> Map.get("schema") do
      # no ref
      %{"type" => type} -> String.to_atom(type)
      %{"$ref" => ref} -> {:component, String.replace(ref, "#/components/schemas/", "")}
    end
  end

  defp parse_path(
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
      group: group,
      response_type: extract_response_type(responses)
    }
  end

  defp parse_path(
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

  defp parse_path(path, %{"post" => args}, component_mapping) do
    # IO.puts("unhandled")
    # IO.inspect(args)
    nil
  end

  defp parse_path(path, %{"delete" => post}, component_mapping) do
  end

  @doc "parse GET functions and generate function definition"
  defp parse_path(
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
       ) do
    %{
      endpoint: path,
      name: Macro.underscore(id),
      summary: summary,
      deprecated?: Map.has_key?(args, "deprecated"),
      arguments: Map.get(args, "parameters", []) |> Enum.map(&parse_get_arguments(&1)),
      method: :get,
      group: group,
      response_type: extract_response_type(responses)
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

    %{
      components: component_mapping,
      functions:
        yml["paths"]
        |> Enum.map(fn {path, field_data} -> parse_path(path, field_data, component_mapping) end)
        |> Enum.filter(&(!is_nil(&1)))
        # TODO: implement form-data
        |> Enum.filter(&Kernel.!=(Map.get(&1, :request_body, nil), :unsupported_content_type))
    }
  end

  def type_to_spec("number"), do: quote(do: float())
  def type_to_spec("integer"), do: quote(do: integer())
  def type_to_spec("boolean"), do: quote(do: boolean())
  def type_to_spec("string"), do: quote(do: String.t())
  # TODO: handle these types here better
  def type_to_spec("array"), do: quote(do: list())
  def type_to_spec("object"), do: quote(do: map())
  def type_to_spec("oneOf"), do: quote(do: any())

  def type_to_spec({:array, {:object, nested_object}}) do
    parsed = type_to_spec({:object, nested_object})
    [parsed]
  end

  def type_to_spec({:array, nested}) do
    quote(do: unquote([type_to_spec(nested)]))
  end

  def type_to_spec({:object, nested}) when is_map(nested) do
    parsed =
      nested
      |> Enum.map(fn {name, type} ->
        {String.to_atom(name), type_to_spec(type)}
      end)

    # manually construct correct AST for maps
    {:%{}, [], parsed}
  end

  # nested component reference
  def type_to_spec({:component, component}) when is_binary(component),
    do: quote(do: unquote(string_to_component(component)).t())

  # fallbacks
  def type_to_spec(i) when is_atom(i), do: type_to_spec(Atom.to_string(i))

  def type_to_spec(x) do
    IO.puts("unhandled: #{inspect(x)}")
    quote(do: any())
  end

  def string_to_component(comp), do: Module.concat(ExOpenAI.Components, comp)

  def keys_to_atoms(string_key_map) when is_map(string_key_map) do
    for {key, val} <- string_key_map,
        into: %{},
        do: {String.to_existing_atom(key), keys_to_atoms(val)}
  end

  def keys_to_atoms(value) when is_list(value), do: Enum.map(value, &keys_to_atoms/1)
  def keys_to_atoms(value), do: value
end

docs = ExOpenAI.get_documentation()

# Generate structs from schema
docs
|> Map.get(:components)
|> Enum.each(fn {name, component} ->
  name =
    name
    |> Macro.camelize()
    |> String.to_atom()
    |> (&Module.concat(ExOpenAI.Components, &1)).()

  struct_fields =
    [component.required_props, component.optional_props]
    |> Enum.map(fn i ->
      Enum.reduce(
        i,
        %{},
        fn item, acc ->
          name = item.name
          type = item.type

          Map.merge(acc, %{
            String.to_atom(name) => quote(do: unquote(ExOpenAI.type_to_spec(type)))
          })
        end
      )
    end)

  # module start
  defmodule name do
    @type t :: %unquote(name){
            unquote_splicing(
              struct_fields
              |> Enum.map(&Map.to_list(&1))
              |> Enum.reduce(&Kernel.++/2)
            )
          }

    with l <- List.first(struct_fields),
         is_empty? <- Enum.empty?(l),
         false <- is_empty? do
      # @enforce_keys Map.keys(l)
    end

    defstruct(struct_fields |> Enum.map(&Map.keys(&1)) |> List.flatten())

    @doc """
    Helper function to return the full AST representation of the type
    This is used so that all atoms in the map are getting allocated recursively.
    Without this, we wouldn't be able to safely do String.to_existing_atom()
    """
    def get_ast() do
      unquote(struct_fields |> Macro.escape())
    end
  end

  # module end
end)

# generate modules
docs
|> Map.get(:functions)
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
        method: method,
        response_type: response_type
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
            Enum.filter(args, &Map.get(&1, :required?))
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
              do: "#{s}\n\n*Example*: `#{inspect(Map.get(i, :example))}`",
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
      response_spec = ExOpenAI.type_to_spec(response_type)

      optional_args =
        merged_optional_args
        |> Enum.reduce([], fn item, acc ->
          name = item.name
          type = item.type

          case acc do
            [] ->
              quote do: {unquote(String.to_atom(name)), unquote(ExOpenAI.type_to_spec(type))}

            val ->
              quote do:
                      {unquote(String.to_atom(name)), unquote(ExOpenAI.type_to_spec(type))}
                      | unquote(val)
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

      opts_name =
        name |> Atom.to_string() |> Kernel.<>("_opts") |> String.to_atom() |> Macro.var(nil)

      @type unquote(opts_name) :: unquote(optional_args)
      @spec unquote(name)(unquote_splicing(spec)) :: {:ok, any()} | {:error, any()}
      @spec unquote(name)(unquote_splicing(spec), unquote([optional_args])) ::
              {:ok, unquote(response_spec)} | {:error, any()}
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
        query =
          Enum.filter(arguments, &Kernel.==(Map.get(&1, :in, ""), "query"))
          |> Enum.reduce(%{}, fn item, acc ->
            Map.put(acc, item.name, Keyword.get(all_passed_args, String.to_atom(item.name)))
          end)
          |> URI.encode_query()

        url = url <> "?" <> query

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

        case ExOpenAI.Client.api_call(method, url, body_params, opts) do
          {:ok, res} ->
            case unquote(response_type) do
              {:component, comp} ->
                # todo: this is not recursive yet, so nested values won't be correctly identified as struct
                # although the typespec is already recursive, so there can be cases where
                # the typespec says a struct is nested, but there isn't
                {:ok, struct(ExOpenAI.string_to_component(comp), ExOpenAI.keys_to_atoms(res))}

              _ ->
                {:ok, res}
            end

          e ->
            e
        end
      end
    end)
  end
end)
