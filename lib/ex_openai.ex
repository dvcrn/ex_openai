defmodule ExOpenAI do
  @moduledoc """
  Auto-generated SDK for OpenAI APIs
  See https://platform.openai.com/docs/api-reference/introduction for further info on REST endpoints
  Make sure to refer to the README on Github to see what is implemented and what isn't yet
  """

  use Application

  alias ExOpenAI.Config

  def start(_type, _args) do
    children = [Config]
    opts = [strategy: :one_for_one, name: ExOpenAI.Supervisor]

    # TODO: find something more elegant for doing this
    # force allocate all possible keys / atoms that are within all available components
    # this allows us to use String.to_existing_atom without having to worry that those
    # atoms aren't allocated yet
    # with {:ok, mods} <- :application.get_key(:ex_openai, :modules) do
    #   # mods
    #   # |> Enum.filter(&(&1 |> Module.split() |> Enum.at(1) == "Components"))
    #   # |> IO.inspect()
    #   # |> Enum.map(& &1.unpack_ast)
    # end

    Supervisor.start_link(children, opts)
  end
end

docs = ExOpenAI.Codegen.get_documentation()

# Generate structs from schema
docs
|> Map.get(:components)
# generate module name: ExOpenAI.Components.X
|> Enum.map(fn {name, c} ->
  {name
   |> ExOpenAI.Codegen.string_to_component(), c}
end)
# ignore stuff that's overwritten
|> Enum.filter(fn {name, _c} -> name not in ExOpenAI.Codegen.module_overwrites() end)
|> Enum.each(fn {name, component} ->
  struct_fields =
    [{:required, component.required_props}, {:optional, component.optional_props}]
    |> Enum.map(fn {kind, i} ->
      Enum.reduce(
        i,
        %{},
        fn item, acc ->
          name = item.name
          type = item.type

          case kind do
            :required ->
              Map.merge(acc, %{
                String.to_atom(name) => quote(do: unquote(ExOpenAI.Codegen.type_to_spec(type)))
              })

            :optional ->
              Map.merge(acc, %{
                String.to_atom(name) =>
                  quote(do: unquote(ExOpenAI.Codegen.type_to_spec(type)) | nil)
              })
          end
        end
      )
    end)

  # module start
  defmodule name do
    use ExOpenAI.Jason

    @moduledoc """
    Schema representing a #{Module.split(name) |> List.last()} within the OpenAI API
    """

    with l <- List.first(struct_fields),
         is_empty? <- Enum.empty?(l),
         false <- is_empty? do
      @enforce_keys Map.keys(l)
    end

    defstruct(struct_fields |> Enum.map(&Map.keys(&1)) |> List.flatten())

    @type t :: %__MODULE__{
            unquote_splicing(
              struct_fields
              |> Enum.map(&Map.to_list(&1))
              |> Enum.reduce(&Kernel.++/2)
            )
          }

    # Inlining the typespec here to have it available during PROD builds, as spec definitions will get stripped
    @typespec quote(
                do: %__MODULE__{
                  unquote_splicing(
                    struct_fields
                    |> Enum.map(&Map.to_list(&1))
                    |> Enum.reduce(&Kernel.++/2)
                  )
                }
              )

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
                with true <- is_atom(args),
                     ats <- Atom.to_string(args),
                     true <- String.contains?(ats, "ExOpenAI.Components") do
                  tree =
                    args.unpack_ast(%{
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
  end

  # module end
end)

# generate modules
docs
|> Map.get(:functions)
# group all the functions by their 'group', to cluster them into Module.Group
|> Enum.reduce(%{}, fn fx, acc ->
  Map.put(acc, fx.group, [fx | Map.get(acc, fx.group, [])])
end)
|> Enum.each(fn {name, functions} ->
  modname =
    name
    |> String.replace("-", "_")
    |> Macro.camelize()
    |> String.to_atom()
    |> (&Module.concat(ExOpenAI, &1)).()

  defmodule modname do
    @moduledoc """
    Modules for interacting with the `#{name}` group of OpenAI APIs

    API Reference: https://platform.openai.com/docs/api-reference/#{name}
    """

    functions
    |> Enum.each(fn fx ->
      %{
        name: function_name,
        summary: summary,
        arguments: args,
        endpoint: endpoint,
        deprecated?: deprecated,
        method: method,
        response_type: response_type,
        group: group
      } = fx

      name = String.to_atom(function_name)

      content_type =
        with body when not is_nil(body) <- Map.get(fx, :request_body, %{}),
             ct <- Map.get(body, :content_type, :"application/json") do
          ct
        end

      merged_required_args =
        case method do
          # POST methods have body arguments on top of positional URL ones
          :post ->
            args ++
              if(is_nil(fx.request_body),
                do: [],
                else: fx.request_body.request_schema.required_props
              )

          :get ->
            Enum.filter(args, &Map.get(&1, :required?))

          :delete ->
            Enum.filter(args, &Map.get(&1, :required?))
        end

      required_args_docstring =
        Enum.map_join(merged_required_args, "\n\n", fn i ->
          s = "- `#{i.name}`"
          s = if Map.has_key?(i, :description), do: "#{s}: #{Map.get(i, :description)}", else: s

          s =
            if Map.get(i, :example, "") != "",
              do: "#{s}\n\n*Example*: `#{Map.get(i, :example)}`",
              else: s

          s
        end)

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

          :delete ->
            Enum.filter(args, &(!Map.get(&1, :required?)))
        end

      optional_args_docstring =
        Enum.map_join(merged_optional_args, "\n\n", fn i ->
          s = "- `#{i.name}`"
          s = if Map.has_key?(i, :description), do: "#{s}: #{Map.get(i, :description)}", else: s

          s =
            if Map.get(i, :example, "") != "",
              do: "#{s}\n\n*Example*: `#{inspect(Map.get(i, :example))}`",
              else: s

          s
        end)

      # convert non-optional args into [arg1, arg2, arg3] representation
      arg_names =
        merged_required_args
        |> Enum.map(&(Map.get(&1, :name) |> String.to_atom() |> Macro.var(nil)))

      # convert non-optional args into spec definition [String.t(), String.t(), etc.] representation
      spec =
        merged_required_args
        |> Enum.map(fn item -> quote do: unquote(ExOpenAI.Codegen.type_to_spec(item.type)) end)

      # convert optional args into keyword list
      response_spec = ExOpenAI.Codegen.type_to_spec(response_type)

      optional_args =
        merged_optional_args
        |> Enum.reduce([], fn item, acc ->
          name = item.name
          type = item.type

          case acc do
            [] ->
              quote do:
                      {unquote(String.to_atom(name)),
                       unquote(ExOpenAI.Codegen.type_to_spec(type))}

            val ->
              quote do:
                      {unquote(String.to_atom(name)),
                       unquote(ExOpenAI.Codegen.type_to_spec(type))}
                      | unquote(val)
          end
        end)
        |> case do
          [] -> []
          e -> [e]
        end

      @doc """
      #{summary |> ExOpenAI.Codegen.fix_openai_links()}

      Endpoint: `https://api.openai.com/v1#{endpoint}`

      Method: #{Atom.to_string(method) |> String.upcase()}

      Docs: https://platform.openai.com/docs/api-reference/#{group}

      ---

      ### Required Arguments:

      #{required_args_docstring |> ExOpenAI.Codegen.fix_openai_links()}


      ### Optional Arguments:

      #{optional_args_docstring |> ExOpenAI.Codegen.fix_openai_links()}
      """
      if deprecated, do: @deprecated("Deprecated by OpenAI")

      # fx without opts
      @spec unquote(name)(unquote_splicing(spec)) ::
              {:ok, unquote(response_spec)} | {:error, any()}

      # fx with opts
      @spec unquote(name)(unquote_splicing(spec), unquote(optional_args)) ::
              {:ok, unquote(response_spec)} | {:error, any()}

      def unquote(name)(unquote_splicing(arg_names), opts \\ []) do
        # store binding so we can't access args of the function later
        binding = binding()

        required_arguments = unquote(Macro.escape(merged_required_args))
        optional_arguments = unquote(Macro.escape(merged_optional_args))
        arguments = required_arguments ++ optional_arguments
        url = "#{unquote(endpoint)}"
        method = unquote(method)
        request_content_type = unquote(content_type)

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

        case ExOpenAI.Client.api_call(method, url, body_params, request_content_type, opts) do
          {:ok, res} ->
            case unquote(response_type) do
              {:component, comp} ->
                # calling unpack_ast here so that all atoms of the given struct are
                # getting allocated. otherwise later usage of keys_to_atom will fail
                ExOpenAI.Codegen.string_to_component(comp).unpack_ast()

                # todo: this is not recursive yet, so nested values won't be correctly identified as struct
                # although the typespec is already recursive, so there can be cases where
                # the typespec says a struct is nested, but there isn't
                {:ok,
                 struct(
                   ExOpenAI.Codegen.string_to_component(comp),
                   ExOpenAI.Codegen.keys_to_atoms(res)
                 )}

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
