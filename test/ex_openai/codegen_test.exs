defmodule ExOpenAITest do
  use ExUnit.Case, async: true

  # in the official openapi docs, causing unknown atoms to be created
  describe "type_to_spec" do
    test "basic types" do
      assert ExOpenAI.Codegen.type_to_spec("number") == {:float, [], []}
      assert ExOpenAI.Codegen.type_to_spec(:number) == {:float, [], []}
      assert ExOpenAI.Codegen.type_to_spec("integer") == {:integer, [], []}
      assert ExOpenAI.Codegen.type_to_spec(:integer) == {:integer, [], []}
      assert ExOpenAI.Codegen.type_to_spec("boolean") == {:boolean, [], []}
      assert ExOpenAI.Codegen.type_to_spec(:boolean) == {:boolean, [], []}
      assert ExOpenAI.Codegen.type_to_spec("bitstring") == {:bitstring, [], []}
      assert ExOpenAI.Codegen.type_to_spec(:bitstring) == {:bitstring, [], []}
      assert ExOpenAI.Codegen.type_to_spec("pid") == {:pid, [], []}
      assert ExOpenAI.Codegen.type_to_spec(:pid) == {:pid, [], []}

      assert ExOpenAI.Codegen.type_to_spec("string") ==
               {{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []}
    end

    test "enum" do
      assert ExOpenAI.Codegen.type_to_spec({:enum, [:hello, :world, :again]}) ==
               {:|, [], [:again, {:|, [], [:world, :hello]}]}
    end

    test "array" do
      assert ExOpenAI.Codegen.type_to_spec("array") == {:list, [], []}
      assert ExOpenAI.Codegen.type_to_spec({:array, "number"}) == [{:float, [], []}]
    end

    test "object" do
      assert ExOpenAI.Codegen.type_to_spec("object") == {:map, [], []}

      assert ExOpenAI.Codegen.type_to_spec({:object, %{"a" => "number"}}) ==
               {:%{}, [], [{:a, {:float, [], []}}]}
    end

    test "array in object" do
      assert ExOpenAI.Codegen.type_to_spec({:object, %{"a" => {:array, "integer"}}}) ==
               {:%{}, [], [{:a, [{:integer, [], []}]}]}
    end

    test "component" do
      assert ExOpenAI.Codegen.type_to_spec({:component, "Foobar"}) ==
               {{:., [], [{:__aliases__, [alias: false], [:ExOpenAI, :Components, :Foobar]}, :t]},
                [], []}
    end

    test "complex nesting" do
      sp =
        {:object,
         %{
           "a" =>
             {:object,
              %{
                "b" => {:array, "string"},
                "c" => {:array, {:component, "Foo"}}
              }}
         }}

      assert ExOpenAI.Codegen.type_to_spec(sp) ==
               {
                 :%{},
                 [],
                 [
                   a:
                     {:%{}, [],
                      [
                        b: [{{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []}],
                        c: [
                          {{:., [],
                            [{:__aliases__, [alias: false], [:ExOpenAI, :Components, :Foo]}, :t]},
                           [], []}
                        ]
                      ]}
                 ]
               }
    end
  end

  test "string_to_component" do
    assert ExOpenAI.Codegen.string_to_component("Hello") == ExOpenAI.Components.Hello
  end

  test "keys_to_atoms" do
    assert ExOpenAI.Codegen.keys_to_atoms(%{
             "a" => 123,
             "b" => %{
               "c" => 23,
               "d" => 456
             }
           }) == %{
             a: 123,
             b: %{
               c: 23,
               d: 456
             }
           }
  end

  describe "parse_component_schema" do
    test "simple component schema" do
      test_schema =
        YamlElixir.read_all_from_string!("""
          properties:
            content:
              type: string
              description: The contents of the message
            name:
              type: string
              description: The name of the user in a multi-user chat
          required:
          - name
        """)
        |> List.first()

      expected = %{
        description: "",
        optional_props: [
          %{
            description: "The contents of the message",
            example: "",
            name: "content",
            type: "string"
          }
        ],
        required_props: [
          %{
            description: "The name of the user in a multi-user chat",
            example: "",
            name: "name",
            type: "string"
          }
        ]
      }

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == expected
    end

    test "nested component schema" do
      test_schema =
        ~S"
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
              object:
                type: string
              document:
                type: integer
              score:
                type: number
    "
        |> YamlElixir.read_all_from_string!()
        |> List.first()

      expected = %{
        description: "",
        optional_props: [
          %{
            description: "",
            example: "",
            name: "data",
            type:
              {:array,
               {:object, %{"document" => "integer", "object" => "string", "score" => "number"}}}
          },
          %{description: "", example: "", name: "model", type: "string"},
          %{description: "", example: "", name: "object", type: "string"}
        ],
        required_props: []
      }

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == expected
    end

    test "super complex nested schema" do
      test_schema =
        ~S"
      properties:
        id:
          type: string
        object:
          type: string
        created:
          type: integer
        model:
          type: string
        choices:
          type: array
          items:
            type: object
            properties:
              text:
                type: string
              index:
                type: integer
              logprobs:
                type: object
                nullable: true
                properties:
                  tokens:
                    type: array
                    items:
                      type: string
                  token_logprobs:
                    type: array
                    items:
                      type: number
                  top_logprobs:
                    type: array
                    items:
                      type: object
                  text_offset:
                    type: array
                    items:
                      type: integer
              finish_reason:
                type: string
        usage:
          type: object
          properties:
            prompt_tokens:
              type: integer
            completion_tokens:
              type: integer
            total_tokens:
              type: integer
          required:
            - prompt_tokens
            - completion_tokens
            - total_tokens
      required:
        - id
        - object
        - created
        - model
        - choices
        "
        |> YamlElixir.read_all_from_string!()
        |> List.first()

      expected = %{
        description: "",
        optional_props: [
          %{
            description: "",
            example: "",
            name: "usage",
            type:
              {:object,
               %{
                 "completion_tokens" => "integer",
                 "prompt_tokens" => "integer",
                 "total_tokens" => "integer"
               }}
          }
        ],
        required_props: [
          %{
            description: "",
            example: "",
            name: "choices",
            type:
              {:array,
               {:object,
                %{
                  "finish_reason" => "string",
                  "index" => "integer",
                  "logprobs" =>
                    {:object,
                     %{
                       "text_offset" => {:array, "integer"},
                       "token_logprobs" => {:array, "number"},
                       "tokens" => {:array, "string"},
                       "top_logprobs" => {:array, "object"}
                     }},
                  "text" => "string"
                }}}
          },
          %{description: "", example: "", name: "created", type: "integer"},
          %{description: "", example: "", name: "id", type: "string"},
          %{description: "", example: "", name: "model", type: "string"},
          %{description: "", example: "", name: "object", type: "string"}
        ]
      }

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == expected
    end

    test "schema with binary string" do
      test_schema =
        YamlElixir.read_all_from_string!(~S"
      properties:
        image:
          description: imgdesc
          type: string
          format: binary
        mask:
          description: maskdesc
          type: string
          format: binary
        prompt:
          description: promptdesc
          type: string
          example: \"A cute baby sea otter wearing a beret\"
      required:
        - prompt
        - image
        ")
        |> List.first()

      expected = %{
        description: "",
        optional_props: [
          %{
            description: "maskdesc",
            example: "",
            name: "mask",
            type: "bitstring"
          }
        ],
        required_props: [
          %{
            description: "imgdesc",
            example: "",
            name: "image",
            type: "bitstring"
          },
          %{
            description: "promptdesc",
            example: "A cute baby sea otter wearing a beret",
            name: "prompt",
            type: "string"
          }
        ]
      }

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == expected
    end

    test "schema with missing properties" do
      test_schema =
        YamlElixir.read_all_from_string!(~S"
      type: object
      description: The parameters the functions accepts, described as a JSON Schema object. See the [guide](/docs/guides/gpt/function-calling) for examples, and the [JSON Schema reference](https://json-schema.org/understanding-json-schema/) for documentation about the format.
      # TODO type this as json schema
      additionalProperties: true
        ")
        |> List.first()

      expected = %{
        optional_props: [],
        required_props: [],
        description:
          "The parameters the functions accepts, described as a JSON Schema object. See the [guide](/docs/guides/gpt/function-calling) for examples, and the [JSON Schema reference](https://json-schema.org/understanding-json-schema/) for documentation about the format."
      }

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == expected
    end
  end

  describe "parse_type" do
    test "simple type" do
      assert ExOpenAI.Codegen.parse_type(%{
               "type" => "string"
             }) == "string"
    end

    test "object" do
      assert ExOpenAI.Codegen.parse_type(%{
               "type" => "object",
               "properties" => %{
                 "foo" => %{
                   "type" => "number"
                 }
               }
             }) == {:object, %{"foo" => "number"}}
    end

    test "component in object" do
      assert ExOpenAI.Codegen.parse_type(%{
               "type" => "object",
               "properties" => %{
                 "foo" => %{
                   "$ref" => "#/components/schemas/SomeComponent"
                 }
               }
             }) == {:object, %{"foo" => {:component, "SomeComponent"}}}
    end

    test "object in object" do
      assert ExOpenAI.Codegen.parse_type(%{
               "type" => "object",
               "properties" => %{
                 "foo" => %{
                   "type" => "object",
                   "properties" => %{
                     "foo" => %{
                       "type" => "integer"
                     }
                   }
                 }
               }
             }) ==
               {:object,
                %{
                  "foo" =>
                    {:object,
                     %{
                       "foo" => "integer"
                     }}
                }}
    end

    test "enum" do
      assert ExOpenAI.Codegen.parse_type(%{
               "type" => "string",
               "enum" => ["system", "user", "assistant"]
             }) == {:enum, [:system, :user, :assistant]}
    end

    test "array" do
      assert ExOpenAI.Codegen.parse_type(%{
               "type" => "array",
               "items" => %{
                 "type" => "integer"
               }
             }) == {:array, "integer"}
    end

    test "component in array" do
      assert ExOpenAI.Codegen.parse_type(%{
               "type" => "array",
               "items" => %{
                 "$ref" => "#/components/schemas/SomeComponent"
               }
             }) == {:array, {:component, "SomeComponent"}}
    end

    test "array in array" do
      assert ExOpenAI.Codegen.parse_type(%{
               "type" => "array",
               "items" => %{
                 "type" => "array",
                 "items" => %{
                   "type" => "integer"
                 }
               }
             }) == {:array, {:array, "integer"}}
    end

    test "object in array" do
      assert ExOpenAI.Codegen.parse_type(%{
               "type" => "array",
               "items" => %{
                 "type" => "object",
                 "properties" => %{
                   "foo" => %{
                     "type" => "integer"
                   }
                 }
               }
             }) == {:array, {:object, %{"foo" => "integer"}}}
    end

    test "array in object" do
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
    end
  end

  describe "parse_path" do
    test "simple path" do
      handler_schema =
        ~S"
    get:
      operationId: mypath
      deprecated: true
      summary: some summary
      parameters:
        - in: path
          name: arg1
          required: true
          schema:
            type: string
            example:
              davinci
          description: &engine_id_description >
            The ID of the engine to use for this request
      responses:
        \"200\":
          description: OK
          content:
            application/json:
              schema:
                type: 'string'
      x-oaiMeta:
        group: somegroup"
        |> YamlElixir.read_all_from_string!()
        |> List.first()

      expected = %{
        arguments: [
          %{example: "davinci", in: "path", name: "arg1", required?: true, type: "string"}
        ],
        deprecated?: true,
        endpoint: "/foo/${engine_id}",
        group: "somegroup",
        method: :get,
        name: "mypath",
        response_type: :string,
        summary: "some summary"
      }

      assert ExOpenAI.Codegen.parse_path("/foo/${engine_id}", handler_schema, %{}) == expected
    end

    test "get path with response component" do
      handler_schema =
        ~S"
    get:
      operationId: retrieveEngine
      deprecated: true
      tags:
      - OpenAI
      summary: Retrieves a model instance, providing basic information about it such as the owner and availability.
      parameters:
        - in: path
          name: engine_id
          required: true
          schema:
            type: string
            example:
              davinci
          description: &engine_id_description >
            The ID of the engine to use for this request
      responses:
        \"200\":
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Engine'
      x-oaiMeta:
        name: Retrieve engine
        group: engines
        path: retrieve"
        |> YamlElixir.read_all_from_string!()
        |> List.first()

      expected = %{
        arguments: [
          %{example: "davinci", in: "path", name: "engine_id", required?: true, type: "string"}
        ],
        deprecated?: true,
        endpoint: "/foo/${engine_id}",
        group: "engines",
        method: :get,
        name: "retrieve_engine",
        response_type: {:component, "Engine"},
        summary:
          "Retrieves a model instance, providing basic information about it such as the owner and availability."
      }

      assert ExOpenAI.Codegen.parse_path("/foo/${engine_id}", handler_schema, %{}) == expected
    end

    test "post path with request component" do
      handler_schema =
        ~S"
    post:
      operationId: retrieveEngine
      deprecated: true
      tags:
      - OpenAI
      summary: summary
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateSearchRequest'
      parameters:
        - in: path
          name: engine_id
          required: true
          schema:
            type: string
            example:
              davinci
          description: &engine_id_description >
            The ID of the engine to use for this request
      responses:
        \"200\":
          description: OK
          content:
            application/json:
              schema:
                type: 'number'
      x-oaiMeta:
        name: Retrieve engine
        group: engines
        path: retrieve"
        |> YamlElixir.read_all_from_string!()
        |> List.first()

      # CreateSearchRequest inside comp_mapping will get expanded into request_schema key
      comp_mapping = %{
        "CreateSearchRequest" => %{
          "type" => "object",
          "properties" => %{
            "foo" => %{
              "type" => "string"
            }
          }
        }
      }

      expected = %{
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

      assert ExOpenAI.Codegen.parse_path("/foo/${engine_id}", handler_schema, comp_mapping) ==
               expected
    end

    test "post with multipart/form-data" do
      handler_schema =
        ~S"
    post:
      operationId: createImageEdit
      tags:
      - OpenAI
      summary: Creates an edited or extended image given an original image and a prompt.
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              $ref: '#/components/schemas/CreateImageEditRequest'
      responses:
        \"200\":
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ImagesResponse'
      x-oaiMeta:
        name: Create image edit
        group: images
        path: create-edit
        beta: true"
        |> YamlElixir.read_all_from_string!()
        |> List.first()

      # CreateSearchRequest inside comp_mapping will get expanded into request_schema key
      comp_mapping = %{
        "CreateImageEditRequest" => %{
          "type" => "object",
          "properties" => %{
            "image" => %{
              "type" => "bitstring"
            },
            "mask" => %{
              "type" => "bitstring"
            }
          }
        }
      }

      expected = %{
        arguments: [],
        deprecated?: false,
        endpoint: "/foo/${engine_id}",
        group: "images",
        method: :post,
        name: "create_image_edit",
        response_type: {:component, "ImagesResponse"},
        summary: "Creates an edited or extended image given an original image and a prompt.",
        request_body: %{
          content_type: :"multipart/form-data",
          request_schema: %{
            "type" => "object",
            "properties" => %{
              "image" => %{"type" => "bitstring"},
              "mask" => %{"type" => "bitstring"}
            }
          },
          required?: true
        }
      }

      assert ExOpenAI.Codegen.parse_path("/foo/${engine_id}", handler_schema, comp_mapping) ==
               expected
    end
  end
end
