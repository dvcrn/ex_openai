defmodule ExOpenAI.Codegen do
  @moduledoc false

  # Codegeneration helpers for parsing the OpenAI openapi documentation and converting it into something easy to work with

  defmodule AstUnpacker do
    @moduledoc false

    defmacro __using__(_opts) do
      quote do
        # Helper function to return the full AST representation of the type and all it's nested types
        # This is used so that all atoms in the map are getting allocated recursively.
        # Without this, we wouldn't be able to safely do String.to_existing_atom()
        @doc false
        def unpack_ast(partial_tree \\ %{}) do
          resolved_mods = Map.get(partial_tree, :resolved_mods, [])
          partial_tree = Map.put(partial_tree, :resolved_mods, resolved_mods)

          case Enum.member?(resolved_mods, __MODULE__) do
            true ->
              # IO.puts("already resolved, skipping")
              partial_tree

            false ->
              res =
                @typespec
                # walk through the AST and find all "ExOpenAI.Components"
                # unpack their AST recursively and merge it all together into
                # the accumulator
                |> Macro.prewalk(partial_tree, fn args, acc ->
                  r =
                    with {:__aliases__, [alias: false], alias} <- args,
                         mod <- Module.concat(alias),
                         ats <- Atom.to_string(mod),
                         true <- String.contains?(ats, "ExOpenAI.Components") do
                      tree =
                        mod.unpack_ast(%{
                          resolved_mods: acc.resolved_mods ++ [__MODULE__]
                        })

                      {:ok, tree}
                    end

                  # merge back into accumulator, otherwise just return AST as is
                  case r do
                    {:ok, res} -> {args, Map.merge(acc, res)}
                    _ -> {args, acc}
                  end
                end)

              {ast, acc} = res

              acc
              |> Map.put(__MODULE__, ast)
          end
        end

        # unpack_ast end
      end
    end
  end

  @doc """
  Modules provided by this package that are not in the openapi docs provided by OpenAI
  So instead of generating those, we just provide a fallback
  """
  def module_overwrites, do: [ExOpenAI.Components.Model]

  @doc """
  Extra opts that should be injected and are not part of the OpenAI docs
  These are custom args that are unique to this package
  """
  def extra_opts_args do
    [
      %{
        description:
          "OpenAI API key to pass directly. If this is specified, it will override the `api_key` config value.",
        example: "",
        name: "openai_api_key",
        type: "string"
      },
      %{
        description:
          "OpenAI API key to pass directly. If this is specified, it will override the `organization_key` config value.",
        example: "",
        name: "openai_organization_key",
        type: "string"
      },
      %{
        description:
          "Which API endpoint to use as base, defaults to https://api.openai.com/v1",
        example: "",
        name: "base_url",
        type: "string"
      }
    ]
  end

  @doc """
  Extracts the group name from a given URL.

  ## Examples

      iex> UrlExtractor.extract_group_from_url("/fine-tunes/{fine_tune_id}")
      "FineTunes"

      iex> UrlExtractor.extract_group_from_url("/files/{file_id}/content")
      "Files"

  """
  defp extract_group_from_url(url) do
    String.split(url, "/")
    |> Enum.at(1)
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
    |> Macro.underscore()
  end

  @doc """
  Inject `stream_to` args when the :stream field is available in the opts
  :stream_to is custom to this package for streaming support, but only relevant if the
  endpoint itself supports streaming of information
  """
  def add_stream_to_opts_args(opts) do
    case Enum.any?(opts, fn el -> Map.get(el, :name, "stream") end) do
      true ->
        [
          %{
            description: "PID or function of where to stream content to",
            example: "",
            name: "stream_to",
            type: {:anyOf, ["pid", "function"]}
          }
          | opts
        ]

      false ->
        opts
    end
  end

  @doc """
  Parses the given component type, returns a flattened representation of that type

  See tests for some examples:
  ```elixir
  assert ExOpenAI.Codegen.parse_type(%{
   "type" => "object",
   "properties" => %{
     "foo" => %{
       "type" => "array",
       "items" => %{
         "type" => "string"
       }
     },
     "bar" => %{
       "type" => "number"
     }
   }
  }) == {:object, %{"foo" => {:array, "string"}, "bar" => "number"}}
  ```
  """
  def parse_type(%{
        "type" => "object",
        "properties" => properties
      }) do
    parsed_obj =
      properties
      |> Enum.map(fn {name, obj} ->
        case obj do
          %{"type" => _type} ->
            {name, parse_type(obj)}

          %{"oneOf" => _oneOf} ->
            {name, parse_type(obj)}

          %{"anyOf" => _oneOf} ->
            {name, parse_type(obj)}

          %{"$ref" => ref} ->
            {name, {:component, String.replace(ref, "#/components/schemas/", "")}}
        end
      end)
      |> Enum.into(%{})

    {:object, parsed_obj}
  end

  def parse_type(%{"$ref" => ref} = _args) do
    {:component, String.replace(ref, "#/components/schemas/", "")}
  end

  def parse_type(%{"anyOf" => anyOf}) do
    {:anyOf,
     Enum.map(anyOf, fn x ->
       parse_type(x)
     end)}
  end

  def parse_type(%{"oneOf" => oneOf}) do
    {:oneOf,
     Enum.map(oneOf, fn x ->
       parse_type(x)
     end)}
  end

  def parse_type(%{
        "type" => "array",
        "items" => items
      }) do
    case items do
      # on nested array, recurse deeper
      %{"type" => "array", "items" => nested} ->
        {:array, parse_type(nested)}

      %{"type" => "object"} ->
        parse_type(items)

      %{"type" => _type} ->
        parse_type(items)

      %{"$ref" => ref} ->
        {:component, String.replace(ref, "#/components/schemas/", "")}

      %{} ->
        :object

      x ->
        IO.puts("invalid type: #{inspect(x)}")
    end
    |> (&{:array, &1}).()
  end

  def parse_type(%{"type" => "string", "enum" => enum_entries}),
    do: {:enum, Enum.map(enum_entries, &String.to_atom/1)}

  def parse_type(%{"type" => "string", "format" => "binary"}), do: "bitstring"

  def parse_type(%{"type" => type}), do: type

  def parse_property(
        %{
          "type" => "array",
          "items" => _items
        } = args
      ) do
    # parse_type returns {:array, XXX} for array type, so in contrast to object we don't need to wrap it again because it's already wrapped
    parse_property(Map.put(args, "type", parse_type(args)))
  end

  def parse_property(%{"anyOf" => anyOf} = args) do
    # parse anyOf array into a list of schemas
    #    "anyOf" => [
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
      name: Map.get(args, "name"),
      description: Map.get(args, "description"),
      required: Map.get(args, "required", false),
      type: {:anyOf, Enum.map(anyOf, fn x -> ExOpenAI.Codegen.parse_type(x) end)}
    }
  end

  def parse_property(%{"oneOf" => oneOf} = args) do
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
      name: Map.get(args, "name"),
      description: Map.get(args, "description"),
      required: Map.get(args, "required", false),
      type: {:oneOf, Enum.map(oneOf, fn x -> ExOpenAI.Codegen.parse_type(x) end)}
    }
  end

  def parse_property(%{"allOf" => allOf} = args) do
    %{
      name: Map.get(args, "name"),
      description: Map.get(args, "description"),
      required: Map.get(args, "required", false),
      type: {:allOf, Enum.map(allOf, fn x -> ExOpenAI.Codegen.parse_type(x) end)}
    }
  end

  # %{
  #   "default" => "auto",
  #   "description" =>
  #     "The number of epochs to train the model for. An epoch refers to one\nfull cycle through the training dataset.\n",
  #   "oneOf" => [
  #     %{"enum" => ["auto"], "type" => "string"},
  #     %{"maximum" => 50, "minimum" => 1, "type" => "integer"}
  #   ]
  # }

  def parse_property(%{
        "name" => name,
        "description" => desc,
        "anyOf" => anyOf,
        "required" => required
      }) do
    %{
      name: name,
      description: desc,
      type: "anyOf",
      required: required,
      oneOf: Enum.map(anyOf, fn x -> ExOpenAI.Codegen.parse_type(x) end)
    }
  end

  def parse_property(
        %{
          "type" => "object",
          "properties" => _properties
        } = args
      ) do
    parse_property(Map.put(args, "type", parse_type(args)))
  end

  def parse_property(
        %{
          "type" => _type,
          "name" => name
        } = args
      ) do
    %{
      type: parse_type(args),
      name: name,
      # optional
      description: Map.get(args, "description", ""),
      # optional
      example: Map.get(args, "example", "")
    }
  end

  def parse_property(%{"$ref" => ref, "name" => name} = args) do
    %{
      name: name,
      type: {:component, String.replace(ref, "#/components/schemas/", "")},
      # optional
      description: Map.get(args, "description", ""),
      # optional
      example: Map.get(args, "example", "")
    }
  end

  def parse_property(args) do
    IO.puts("Unknown property: #{inspect(args)}")
  end

  defp parse_properties(props) when is_list(props) do
    Enum.map(props, &parse_property(&1))
  end

  @doc """
  Parses the given schema recursively into a normalize representation such as `%{description: "", example: "", name: "", type: ""}`.

  A "component schema" is what is defined in the original OpenAI openapi document under the path /components/schema and could look like this:

  ```
    ChatCompletionRequestMessage:
      type: object
      properties:
      content:
        type: string
        description: The contents of the message
      name:
        type: string
        description: The name of the user in a multi-user chat
      required:
      - name
  ```

  - `required_props` will consist of all properties that were listed under the "required" list
  - `optional_props` will be all others

  "Type" will get normalized into a internal representation consiting of all it's nested children that can be unfolded easily later on:
  - "string" -> "string"
  - "integer" -> "integer"
  - "object" -> {:object, %{nestedobject...}}
  - "array" -> {:array, "string" | "integer" | etc}
  """
  def parse_component_schema(%{"properties" => props, "required" => required} = full_schema) do
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
      description: Map.get(full_schema, "description", ""),
      kind: :component,
      required_props: parse_properties(required_props),
      optional_props: parse_properties(optional_props)
    }
  end

  # Handling for when the component isn't a full component by it's own, but instead embeds other components
  def parse_component_schema(%{"oneOf" => _oneOf} = args) do
    %{
      kind: :oneOf,
      # piggybacking parse_property which handles parsing of "oneOf" already
      components: parse_property(args) |> Map.get(:type) |> elem(1),
      required_props: [],
      optional_props: []
    }
  end

  def parse_component_schema(%{"allOf" => _allOf} = args) do
    %{
      kind: :allOf,
      # piggybacking parse_property which handles parsing of "oneOf" already
      components: parse_property(args) |> Map.get(:type) |> elem(1),
      required_props: [],
      optional_props: []
    }
  end

  def parse_component_schema(%{"properties" => props}),
    do: parse_component_schema(%{"properties" => props, "required" => []})

  # case for no props
  def parse_component_schema(%{"description" => _} = args),
    do: parse_component_schema(args |> Map.put("properties", %{}) |> Map.put("required", []))

  @spec parse_get_schema(map()) :: %{type: String.t(), example: String.t()}
  defp parse_get_schema(%{"type" => type, "example" => example}) do
    %{type: type, example: example}
  end

  defp parse_get_schema(%{"type" => _type} = args),
    do: parse_get_schema(Map.put(args, "example", ""))

  defp parse_request_body(%{"required" => required, "content" => content}, component_mapping) do
    {content_type, rest} =
      content
      |> Map.to_list()
      |> List.first()

    # resolve the object ref to the actual component to get the schema
    ref =
      (rest["schema"]["$ref"] || "")
      |> String.replace_prefix("#/components/schemas/", "")

    %{
      required?: required,
      content_type: String.to_atom(content_type),
      # rest: rest,
      # ref: ref,
      request_schema: Map.get(component_mapping, ref)
    }
  end

  # case for when required is not set
  defp parse_request_body(%{"content" => _content} = args, component_mapping) do
    parse_request_body(Map.put(args, "required", false), component_mapping)
  end

  defp parse_request_body(nil, _) do
    nil
  end

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

  defp extract_response_type(%{"200" => %{"content" => content}}) do
    content
    # [["application/json", %{}]]
    |> Map.to_list()
    # ["application/json", %{}]
    |> List.first()
    # %{}
    |> Kernel.elem(1)
    |> Map.get("schema")
    |> case do
      # no ref
      %{"type" => type} ->
        String.to_atom(type)

      %{"$ref" => ref} ->
        {:component, String.replace(ref, "#/components/schemas/", "")}

      %{"oneOf" => list} ->
        {:oneOf,
         Enum.map(list, fn %{"$ref" => ref} ->
           {:component, String.replace(ref, "#/components/schemas/", "")}
         end)}
    end
  end

  @doc """
  Parses a given "path". A path is what is mapped under the "paths" key of the OpenAI openapi docs, and represents an API endpoint (GET, POST, DELETE, PUT)

  The result is a normalized Map representation of the parsed path, including arguments, body and return values

  - `response_type` will be the type value (:string, :integer). Components are represented as {:component, %{"a" => "string"}}
  - `request_body` on the other hand will not reference the request component but instead inline it. This decision was made to have all type information available as is for the signature, whereas it is not as important for the response

  Example parsed construct:
  ```elixir
  %{
    arguments: [
      %{example: "davinci", in: "path", name: "engine_id", required?: true, type: "string"}
    ],
    deprecated?: true,
    endpoint: "/foo/${engine_id}",
    group: "engines",
    method: :post,
    name: "retrieve_engine",
    response_type: :number,
    summary: "summary",
    request_body: %{
      content_type: :"application/json",
      request_schema: %{"properties" => %{"foo" => %{"type" => "string"}}, "type" => "object"},
      required?: true
    }
    }
  ```

  Example from the API docs:
  ```yaml
   /engines:
    get:
      operationId: listEngines
      deprecated: true
      tags:
      - OpenAI
      summary: Lists the currently available (non-finetuned) models, and provides basic information about each one such as the owner and availability.
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ListEnginesResponse'
      x-oaiMeta:
        name: List engines
        group: engines
        path: list
    ```

  """
  def parse_path(
        path,
        %{
          "post" =>
            %{
              "operationId" => id,
              "summary" => summary,
              "requestBody" => body,
              "responses" => responses,
              "x-oaiMeta" => _meta
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
      group: extract_group_from_url(path),
      response_type: extract_response_type(responses)
    }
  end

  def parse_path(
        path,
        %{
          "post" =>
            %{
              "operationId" => _id,
              "summary" => _summary,
              "responses" => _responses,
              "x-oaiMeta" => _meta
            } = args
        },
        component_mapping
      ) do
    parse_path(path, %{"post" => Map.put(args, "requestBody", nil)}, component_mapping)
  end

  def parse_path(path, %{"delete" => args}, component_mapping) do
    # delete is kind of same as with GET, so we can just parse with the GET path and swap out the method :)

    parse_path(path, %{"get" => args}, component_mapping)
    |> Map.put(:method, :delete)
  end

  # "parse GET functions and generate function definition"
  def parse_path(
        path,
        %{
          "get" =>
            %{
              "operationId" => id,
              "summary" => summary,
              "responses" => responses,
              "x-oaiMeta" => _meta
            } = args
        },
        _component_mapping
      ) do
    %{
      endpoint: path,
      name: Macro.underscore(id),
      summary: summary,
      deprecated?: Map.has_key?(args, "deprecated"),
      arguments: Map.get(args, "parameters", []) |> Enum.map(&parse_get_arguments(&1)),
      method: :get,
      group: extract_group_from_url(path),
      response_type: extract_response_type(responses)
    }
  end

  def parse_path(path, args, _component_mapping) do
    IO.puts("unhandled path: #{inspect(path)} - #{inspect(args)}")
    nil
  end

  def get_documentation do
    {:ok, yml} =
      File.read!("#{__DIR__}/docs/docs.yaml")
      |> YamlElixir.read_from_string()

    component_mapping =
      yml["components"]["schemas"]
      |> Enum.reduce(%{}, fn {name, value}, acc ->
        Map.put(acc, name, parse_component_schema(value))
      end)

    # iterate through all URL pathes and generate a normalized map
    # eg path = /assistants/{xxx}
    # field_data = %{"get" => xxx, "post" => yyy}
    res = %{
      components: component_mapping,
      functions:
        yml["paths"]
        |> Enum.map(fn {path, field_data} ->
          # iterate through get/post/delete/put options and call parse_path for each
          # parse_path will then generate the normalized map for the method
          Enum.map(field_data, fn {verb, args} ->
            # parse path expects a %{"get" => xxx} as arg
            parse_path(path, %{verb => args}, component_mapping)
          end)
        end)
        |> List.flatten()
        |> Enum.filter(&(!is_nil(&1)))
    }

    res
  end

  def type_to_spec("pid"), do: quote(do: pid())
  def type_to_spec("function"), do: quote(do: fun())
  def type_to_spec("number"), do: quote(do: float())
  def type_to_spec("integer"), do: quote(do: integer())
  def type_to_spec("boolean"), do: quote(do: boolean())
  def type_to_spec("string"), do: quote(do: String.t())
  def type_to_spec("bitstring"), do: quote(do: bitstring() | {String.t(), bitstring()})
  # TODO: handle these types here better
  def type_to_spec("array"), do: quote(do: list())
  def type_to_spec("object"), do: quote(do: map())
  def type_to_spec("oneOf"), do: quote(do: any())
  def type_to_spec("allOf"), do: quote(do: any())
  def type_to_spec("anyOf"), do: quote(do: any())

  def type_to_spec({:anyOf, nested}) do
    nested
    |> Enum.map(&type_to_spec/1)
    |> Enum.reduce(&{:|, [], [&1, &2]})
  end

  def type_to_spec({:oneOf, nested}) do
    nested
    |> Enum.map(&type_to_spec/1)
    |> Enum.reduce(&{:|, [], [&1, &2]})
  end

  def type_to_spec({:array, {:object, nested_object}}) do
    parsed = type_to_spec({:object, nested_object})
    [parsed]
  end

  def type_to_spec({:array, nested}) do
    quote(do: unquote([type_to_spec(nested)]))
  end

  def type_to_spec({:enum, l}) when is_list(l) do
    Enum.reduce(l, &{:|, [], [&1, &2]})
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
  def type_to_spec({:component, component}) when is_binary(component) do
    # remote types to modules are represented with [:OpenAI, :Component, :X]
    mod = string_to_component(component) |> Module.split() |> Enum.map(&String.to_atom/1)
    {{:., [], [{:__aliases__, [alias: false], mod}, :t]}, [], []}
  end

  # fallbacks
  def type_to_spec(i) when is_atom(i), do: type_to_spec(Atom.to_string(i))

  def type_to_spec(x) do
    IO.puts("type_to_spec: unhandled: #{inspect(x)}")
    quote(do: any())
  end

  def string_to_component(comp), do: Module.concat(ExOpenAI.Components, comp)

  def keys_to_atoms(string_key_map) when is_map(string_key_map) do
    for {key, val} <- string_key_map,
        into: %{},
        do: {
          try do
            String.to_existing_atom(key)
          rescue
            ArgumentError ->
              IO.puts(
                "Warning! Found non-existing atom returning by OpenAI API: :#{key}.\nThis may mean that OpenAI has updated it's API, or that the key was not included in their official openapi reference.\nGoing to load this atom now anyway, but as converting a lot of unknown data into atoms can result in a memory leak, watch out for these messages. If you see a lot of them, something may be wrong."
              )

              String.to_atom(key)
          end,
          keys_to_atoms(val)
        }
  end

  def keys_to_atoms(value) when is_list(value), do: Enum.map(value, &keys_to_atoms/1)
  def keys_to_atoms(value), do: value

  @spec fix_openai_links(String.t()) :: String.t()
  def fix_openai_links(s) do
    s
    |> String.replace("/docs/", "https://platform.openai.com/docs/")
    |> String.replace("/tokenizer", "https://platform.openai.com/tokenizer")
  end
end
