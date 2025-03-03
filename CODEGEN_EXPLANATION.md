# Understanding ex_openai Code Generation Architecture

## Overview

The `ex_openai` library is an Elixir SDK for the OpenAI API that leverages metaprogramming to auto-generate most of its code directly from OpenAI's API documentation. This design ensures the SDK remains current with OpenAI's API without requiring manual updates for each API change.

## Code Generation Process - Step by Step

### 1. Reading and Parsing "docs.yaml"

The process begins with parsing OpenAI's API documentation, stored as a YAML file at `lib/ex_openai/docs/docs.yaml`:

```elixir
def get_documentation do
  {:ok, yml} =
    File.read!("#{__DIR__}/docs/docs.yaml")
    |> YamlElixir.read_from_string()

  # Process components and functions...
end
```

**Short Example:**

In your "docs.yaml," suppose you have:

```yaml
paths:
  /completions:
    post:
      operationId: createCompletion
      summary: Create a new completion
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CompletionRequest'
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CompletionResponse'

components:
  schemas:
    CompletionRequest:
      type: object
      required:
        - model
        - prompt
      properties:
        model:
          type: string
        prompt:
          type: string
        max_tokens:
          type: integer
    CompletionResponse:
      type: object
      properties:
        id:
          type: string
        choices:
          type: array
          items:
            type: string
```

Your code calls `ExOpenAI.Codegen.get_documentation/0` to parse this file, returning a structure like:

```elixir
%{
  components: %{
    "CompletionRequest" => %{kind: :component, required_props: [...], optional_props: [...]},
    "CompletionResponse" => %{kind: :component, ...}
  },
  functions: [
    %{
      endpoint: "/completions",
      name: "create_completion",
      method: :post,
      request_body: %{...},
      response_type: {:component, "CompletionResponse"},
      group: "completions"
    }
  ]
}
```

### 2. Converting Raw JSON Schema Types (parse_type/1)

The type system converts OpenAI's type definitions to an intermediate Elixir representation:

```elixir
def parse_type(%{"type" => "string", "enum" => enum_entries}),
  do: {:enum, Enum.map(enum_entries, &String.to_atom/1)}

def parse_type(%{"type" => "array", "items" => items}),
  do: {:array, parse_type(items)}

def parse_type(%{"$ref" => ref}),
  do: {:component, String.replace(ref, "#/components/schemas/", "")}

def parse_type(%{"type" => type}),
  do: type
```

**Short Example:**

If the docs.yaml contains:

```json
{
  "type": "array",
  "items": {
    "type": "string"
  }
}
```

The `parse_type` function sees `"type": "array"` and `"items": {"type": "string"}`. It transforms this into an intermediate representation:

```elixir
{:array, "string"}
```

Similarly, if you have:

```json
{
  "type": "object",
  "properties": {
    "role": {
      "type": "string",
      "enum": ["system", "user"]
    }
  }
}
```

`parse_type` will return:

```elixir
{:object, %{"role" => {:enum, [:system, :user]}}}
```

This representation is used later for building Elixir typespecs or struct fields.

### 3. Creating a Normalized Component Schema (parse_component_schema/1)

Component schemas are transformed into a normalized Elixir representation:

```elixir
def parse_component_schema(%{"properties" => props, "required" => required} = full_schema) do
  # Process properties and separate required vs optional
  %{
    description: Map.get(full_schema, "description", ""),
    kind: :component,
    required_props: parse_properties(required_props),
    optional_props: parse_properties(optional_props)
  }
end
```

**Short Example:**

Consider a component:

```yaml
CompletionRequest:
  type: object
  required:
    - "model"
  properties:
    model:
      type: "string"
    max_tokens:
      type: "integer"
```

`parse_component_schema/1` generates something like:

```elixir
%{
  kind: :component,
  description: "...",
  required_props: [
    %{
      name: "model",
      type: "string",
      description: "",
      example: ""
    }
  ],
  optional_props: [
    %{
      name: "max_tokens",
      type: "integer",
      description: "",
      example: ""
    }
  ]
}
```

Notice how the function separates `required_props` from `optional_props`, based on the "required" array in the YAML definition.

The function also handles special cases like `oneOf` and `allOf` types. Both of these are handled similarly, creating a type representation that allows for multiple possible type variants.

### 4. Extracting Endpoint Definitions (parse_path/3)

For each API endpoint, the library processes HTTP methods and parameters:

```elixir
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
  # Extract endpoint data
end
```

The library handles GET, POST, and DELETE methods. If it encounters an unsupported HTTP verb or path definition, it logs "unhandled path: [path] - [args]". This helps users identify when an OpenAI API endpoint isn't implemented in the library, which can be useful for troubleshooting or requesting new features.

**Short Example:**

If your docs.yaml has:

```yaml
/completions:
  post:
    operationId: createCompletion
    summary: Create a new completion
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/CompletionRequest'
    responses:
      "200":
        description: OK
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CompletionResponse'
```

The `parse_path` function produces a data structure such as:

```elixir
%{
  endpoint: "/completions",
  name: "create_completion",
  summary: "Create a new completion",
  deprecated?: false,
  arguments: [],  # no explicit path/query parameters in this example
  method: :post,
  request_body: %{
    required?: true,
    content_type: :application/json,
    request_schema: <Parsed shaping of "CompletionRequest">
  },
  group: "completions",
  response_type: {:component, "CompletionResponse"}
}
```

### 5. Type Spec Generation

After parsing types, they're converted to Elixir typespecs:

```elixir
def type_to_spec("string"), do: quote(do: String.t())
def type_to_spec("integer"), do: quote(do: integer())
def type_to_spec("number"), do: quote(do: float())
def type_to_spec("boolean"), do: quote(do: boolean())
def type_to_spec("bitstring"), do: quote(do: bitstring() | {String.t(), bitstring()})

def type_to_spec({:array, nested}), do: quote(do: unquote([type_to_spec(nested)]))

def type_to_spec({:enum, l}) when is_list(l), do:
  Enum.reduce(l, &{:|, [], [&1, &2]})

def type_to_spec({:component, component}) when is_binary(component) do
  mod = string_to_component(component) |> Module.split() |> Enum.map(&String.to_atom/1)
  {{:., [], [{:__aliases__, [alias: false], mod}, :t]}, [], []}
end
```

This generates proper Elixir typespecs for documentation and dialyzer analysis.

### 6. Generating Modules for Components

For each component schema, a corresponding Elixir module with a struct is generated:

```elixir
defmodule name do
  use ExOpenAI.Jason

  @enforce_keys Map.keys(l)
  defstruct(struct_fields |> Enum.map(&Map.keys(&1)) |> List.flatten())

  @type t :: %__MODULE__{
    unquote_splicing(
      struct_fields
      |> Enum.map(&Map.to_list(&1))
      |> Enum.reduce(&Kernel.++/2)
    )
  }

  use ExOpenAI.Codegen.AstUnpacker
end
```

Before generating these modules, the code checks against `ExOpenAI.Codegen.module_overwrites()`, which returns a list of modules that should NOT be auto-generated (currently only `ExOpenAI.Components.Model`). These modules are provided manually instead, allowing for customization beyond what the OpenAI docs specify.

**Short Example:**

Given the parsed schema for "CompletionRequest," the code dynamically builds an Elixir module:

```elixir
defmodule ExOpenAI.Components.CompletionRequest do
  @enforce_keys [:model]  # from required props
  defstruct [:model, :max_tokens]

  @type t :: %__MODULE__{
    model: String.t(),
    max_tokens: integer() | nil
  }

  # Includes AST unpacking for atom allocation
  use ExOpenAI.Codegen.AstUnpacker
end
```

This happens for each "component" in docs.yaml. Components with allOf / oneOf / anyOf become specialized union types.

### 7. Generating Endpoint Modules and Functions

API functions are grouped by their path prefix, and a module is generated for each group:

```elixir
defmodule modname do
  @moduledoc """
  Modules for interacting with the `#{name}` group of OpenAI APIs
  """

  # Function definitions...
end
```

**Short Example:**

Given a single parsed path data structure:

```elixir
%{
  endpoint: "/completions",
  name: "create_completion",
  method: :post,
  group: "completions",
  request_body: %{
    request_schema: <Parsed "CompletionRequest">,
  },
  response_type: {:component, "CompletionResponse"}
}
```

ExOpenAI creates a module `ExOpenAI.Completions` with a function `create_completion/2`:

```elixir
defmodule ExOpenAI.Completions do
  @doc """
  Create a new completion

  Required Arguments:
  - model: string

  Optional Arguments:
  - max_tokens: integer

  Endpoint: POST /completions
  Docs: https://platform.openai.com/docs/api-reference/completions
  """
  @spec create_completion(String.t(), keyword()) ::
          {:ok, ExOpenAI.Components.CompletionResponse.t()} | {:error, any()}
  def create_completion(model, opts \\ []) do
    # Construct body from arguments
    body_params = [model: model] ++ opts
    # Delegates to the client
    ExOpenAI.Config.http_client().api_call(
      :post,
      "/completions",
      body_params,
      :"application/json",
      opts,
      &convert_response(&1, {:component, "CompletionResponse"})
    )
  end
end
```

For each function, the generator creates:
- Documentation with parameter descriptions and examples
- Type specifications for both required and optional arguments
- Return type specifications
- Function implementation that handles the API request

Additionally, `ExOpenAI.Codegen.extra_opts_args()` injects additional standard options into every generated function's options:
- `openai_api_key`: Overrides the global API key config
- `openai_organization_key`: Overrides the global organization key config
- `base_url`: Customizes which API endpoint to use as base

For functions that support streaming, the code uses `ExOpenAI.Codegen.add_stream_to_opts_args()` to inject a `stream_to` parameter, allowing users to specify a PID or function to receive streaming content.

### 8. Request Processing

The generated functions create properly formatted API calls by:

1. Extracting required parameters from function arguments
2. Extracting optional parameters from the keyword list
3. Constructing the API URL by injecting path parameters
4. Adding query parameters to the URL
5. Building the request body for POST requests
6. Handling the response and converting it to the appropriate Elixir types

```elixir
# Constructing URL with path parameters
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

# Adding query parameters
query =
  Enum.filter(arguments, &Kernel.==(Map.get(&1, :in, ""), "query"))
  |> Enum.filter(&(!is_nil(Keyword.get(all_passed_args, String.to_atom(&1.name
    |> Enum.filter(&(!is_nil(Keyword.get(all_passed_args, String.to_atom(&1.name)))))
    |> Enum.reduce(%{}, fn item, acc ->
      Map.put(acc, item.name, Keyword.get(all_passed_args, String.to_atom(item.name)))
    end)
    |> URI.encode_query()

# Calling the API
ExOpenAI.Config.http_client().api_call(
  method,
  url,
  body_params,
  request_content_type,
  opts,
  convert_response
)
```

### 9. Client Implementation

The API client (`ExOpenAI.Client`) handles the actual HTTP requests:

```elixir
def api_post(url, params \\ [], request_options \\ [], convert_response) do
  body =
    params
    |> Enum.into(%{})
    |> strip_params()
    |> Jason.encode()
    |> elem(1)

  # Set up headers, options, etc.

  url
  |> add_base_url(base_url)
  |> post(body, headers, request_options)
  |> handle_response()
  |> convert_response.()
end
```

Key features:
1. Support for different HTTP methods (GET, POST, DELETE)
2. Proper header handling for authorization
3. Support for multipart forms for file uploads
4. Response processing

### 10. Streaming Support

The library implements sophisticated streaming support for OpenAIs Server-Sent Events:

```elixir
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
```

This supports:
1. Callback functions for streaming data processing
2. Streaming to separate processes
3. Proper error handling and cleanup

For any endpoint that supports streaming, the `add_stream_to_opts_args` function automatically injects the `stream_to` parameter option, making it available to users without manual implementation for each function.

### 11. AST Unpacking for Atom Allocation

A crucial part of the system is ensuring atoms are pre-allocated:

```elixir
defmodule AstUnpacker do
  defmacro __using__(_opts) do
    quote do
      def unpack_ast(partial_tree \\ %{}) do
        resolved_mods = Map.get(partial_tree, :resolved_mods, [])
        partial_tree = Map.put(partial_tree, :resolved_mods, resolved_mods)

        case Enum.member?(resolved_mods, __MODULE__) do
          true ->
            partial_tree
          false ->
            # Walk through the AST and find all components
            # Recursively unpack their AST
        end
      end
    end
  end
end
```

Every generated component module uses `use ExOpenAI.Codegen.AstUnpacker`, which injects the `unpack_ast` function. This function is crucial for:

1. Walking recursively through all component references in a type
2. Pre-allocating atoms for every field and nested field that might be used in API responses
3. Ensuring `String.to_existing_atom/1` can be safely used in response handling

The `keys_to_atoms` function is responsible for converting JSON response keys from strings to atoms:

```elixir
def keys_to_atoms(string_key_map) when is_map(string_key_map) do
  for {key, val} <- string_key_map,
      into: %{},
      do: {
        try do
          String.to_existing_atom(key)
        rescue
          ArgumentError ->
            Logger.debug(
              "Warning! Found non-existing atom returning by OpenAI API: :#{key}.\n" <>
              "This may mean that OpenAI has updated it's API..."
            )
            String.to_atom(key)
        end,
        keys_to_atoms(val)
      }
end
```

This function tries to convert every key to an existing atom first, and if that fails, it:
1. Logs a warning (this is important for identifying API changes from OpenAI)
2. Creates the atom anyway (with a caution about potential memory leaks)
3. Recursively processes nested maps and lists

This combination of AST unpacking and careful atom handling ensures the library safely handles JSON responses from the OpenAI API.

## Contributing to the Code Generation

To add or extend functionality:

1. Update docs.yaml under the correct OpenAI endpoints and components.
2. If a component includes new or unusual fields (e.g., new "image" type), modify `parse_type/1` or `parse_property/1` in codegen.ex to translate to the correct Elixir structure.
3. If an endpoint returns a brand-new top-level schema, reference it in the responses field so `parse_path/3` can link it.
4. If you need custom logic for certain endpoints (e.g., special streaming behavior), you can override how the code is generated (e.g., by hooking into or modifying the final expansions in lib/ex_openai.ex).
5. If you need to provide a custom implementation for a component, add it to `ExOpenAI.Codegen.module_overwrites()` to prevent auto-generation.
6. For new global options, consider adding them to `ExOpenAI.Codegen.extra_opts_args()`.
