defmodule ExOpenAI.Codegen.FinalizeSchemaTest do
  use ExUnit.Case, async: true

  describe "finalize_schema" do
    test "finalizes schema with correct sub-components" do
      # some nested components
      # CreateModelResponseProperties embeds ModelResponseProperties
      component_mapping = %{
        "CreateModelResponseProperties" => %{
          kind: :allOf,
          components: [component: "ModelResponseProperties"],
          required_props: [],
          optional_props: [],
          required_prop_keys: []
        },
        "ModelResponseProperties" => %{
          description: "",
          kind: :component,
          required_props: [],
          optional_props: [
            %{
              name: "model",
              type:
                {:anyOf,
                 [
                   "string",
                   {:enum,
                    [
                      :"o3-mini",
                      :"o3-mini-2025-01-31",
                      :o1
                    ]}
                 ]},
              description:
                "Model ID used to generate the response, like `gpt-4o` or `o1`. OpenAI\noffers a wide range of models with different capabilities, performance\ncharacteristics, and price points. Refer to the [model guide](/docs/models)\nto browse and compare available models.\n",
              required: false
            }
          ]
        }
      }

      test_schema = %{
        kind: :allOf,
        components: [
          {:component, "CreateModelResponseProperties"},
          %{
            description: "",
            kind: :component,
            required_props: [
              %{
                name: "messages",
                type: {:array, {:component, "ChatCompletionRequestMessage"}},
                description:
                  "A list of messages comprising the conversation so far. Depending on the\n[model](/docs/models) you use, different message types (modalities) are\nsupported, like [text](/docs/guides/text-generation),\n[images](/docs/guides/vision), and [audio](/docs/guides/audio).\n",
                example: ""
              }
            ],
            optional_props: [
              %{
                name: "tools",
                type: {:array, {:component, "ChatCompletionTool"}},
                description:
                  "A list of tools the model may call. Currently, only functions are supported as a tool. Use this to provide a list of functions the model may generate JSON inputs for. A max of 128 functions are supported.\n",
                example: ""
              },
              %{
                name: "top_logprobs",
                type: "integer",
                description:
                  "An integer between 0 and 20 specifying the number of most likely tokens to\nreturn at each token position, each with an associated log probability.\n`logprobs` must be set to `true` if this parameter is used.\n",
                example: ""
              }
            ]
          }
        ],
        required_props: [],
        optional_props: [],
        required_prop_keys: ["model", "messages"]
      }

      expected =
        {"Something",
         %{
           description: "",
           kind: :component,
           required_props: [
             %{
               name: "messages",
               type: {:array, {:component, "ChatCompletionRequestMessage"}},
               description:
                 "A list of messages comprising the conversation so far. Depending on the\n[model](/docs/models) you use, different message types (modalities) are\nsupported, like [text](/docs/guides/text-generation),\n[images](/docs/guides/vision), and [audio](/docs/guides/audio).\n",
               example: ""
             },
             %{
               name: "model",
               type:
                 {:anyOf,
                  [
                    "string",
                    {:enum,
                     [
                       :"o3-mini",
                       :"o3-mini-2025-01-31",
                       :o1
                     ]}
                  ]},
               description:
                 "Model ID used to generate the response, like `gpt-4o` or `o1`. OpenAI\noffers a wide range of models with different capabilities, performance\ncharacteristics, and price points. Refer to the [model guide](/docs/models)\nto browse and compare available models.\n",
               required: false
             }
           ],
           optional_props: [
             %{
               name: "tools",
               type: {:array, {:component, "ChatCompletionTool"}},
               description:
                 "A list of tools the model may call. Currently, only functions are supported as a tool. Use this to provide a list of functions the model may generate JSON inputs for. A max of 128 functions are supported.\n",
               example: ""
             },
             %{
               name: "top_logprobs",
               type: "integer",
               description:
                 "An integer between 0 and 20 specifying the number of most likely tokens to\nreturn at each token position, each with an associated log probability.\n`logprobs` must be set to `true` if this parameter is used.\n",
               example: ""
             }
           ]
         }}

      actual = ExOpenAI.Codegen.finalize_schema({"Something", test_schema}, component_mapping)

      # the final should be a combined map of all the nested objects that are referenced
      # the final optional_props and required_props reflects what was provided in
      #         required_prop_keys: ["model", "messages"]
      assert actual == expected

      {name, content} = actual

      # should keep existing name
      assert name == "Something"
      # required should be 2 elemnts now, because ["model", "messages"] are 2
      assert Enum.count(content.required_props) == 2

      # this one should be "model"
      assert Enum.find(content.required_props, fn prop -> prop.name == "model" end) != nil
      # this one should be "messages"
      assert Enum.find(content.required_props, fn prop -> prop.name == "messages" end) != nil

      # check that none of the required fields are in options
      required_prop_names = content.required_props |> Enum.map(& &1.name)
      optional_prop_names = content.optional_props |> Enum.map(& &1.name)

      intersection =
        MapSet.intersection(MapSet.new(required_prop_names), MapSet.new(optional_prop_names))

      assert Enum.count(intersection) == 0
    end
  end
end
