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

      assert ExOpenAI.Codegen.type_to_spec("string") ==
               {{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []}
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
               {{:., [], [ExOpenAI.Components.Foobar, :t]}, [], []}
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
                        c: [{{:., [], [ExOpenAI.Components.Foo, :t]}, [], []}]
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
end
