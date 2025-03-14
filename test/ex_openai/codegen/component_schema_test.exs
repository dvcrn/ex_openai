defmodule ExOpenAI.Codegen.ComponentSchemaTest do
  use ExUnit.Case, async: true

  describe "parse_component_schema/1 with additionalProperties" do
    test "object schema with no properties and additionalProperties=false" do
      test_schema =
        YamlElixir.read_all_from_string!(~S"
        type: object
        additionalProperties: false
        description: 'Empty object with strict property definition'
        ")
        |> List.first()

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == %{
               kind: :component,
               description: "Empty object with strict property definition",
               required_props: [],
               optional_props: []
             }
    end
  end

  describe "parse_component_schema" do
    test "CreateChatCompletionRequest" do
      test_schema =
        YamlElixir.read_all_from_string!(~s"""
          allOf:
            - $ref: "#/components/schemas/CreateModelResponseProperties"
            - type: object
              properties:
                messages:
                  description: >
                    A list of messages comprising the conversation so far. Depending
                    on the

                    [model](/docs/models) you use, different message types
                    (modalities) are

                    supported, like [text](/docs/guides/text-generation),

                    [images](/docs/guides/vision), and [audio](/docs/guides/audio).
                  type: array
                  minItems: 1
                  items:
                    $ref: "#/components/schemas/ChatCompletionRequestMessage"
                modalities:
                  $ref: "#/components/schemas/ResponseModalities"
                reasoning_effort:
                  $ref: "#/components/schemas/ReasoningEffort"
                max_completion_tokens:
                  description: >
                    An upper bound for the number of tokens that can be generated
                    for a completion, including visible output tokens and [reasoning
                    tokens](/docs/guides/reasoning).
                  type: integer
                  nullable: true
                frequency_penalty:
                  type: number
                  default: 0
                  minimum: -2
                  maximum: 2
                  nullable: true
                  description: >
                    Number between -2.0 and 2.0. Positive values penalize new tokens
                    based on

                    their existing frequency in the text so far, decreasing the
                    model's

                    likelihood to repeat the same line verbatim.
                presence_penalty:
                  type: number
                  default: 0
                  minimum: -2
                  maximum: 2
                  nullable: true
                  description: >
                    Number between -2.0 and 2.0. Positive values penalize new tokens
                    based on

                    whether they appear in the text so far, increasing the model's
                    likelihood

                    to talk about new topics.
                web_search_options:
                  type: object
                  title: Web search
                  description: >
                    This tool searches the web for relevant results to use in a
                    response.

                    Learn more about the [web search
                    tool](/docs/guides/tools-web-search?api-mode=chat).
                  properties:
                    user_location:
                      type: object
                      nullable: true
                      required:
                        - type
                        - approximate
                      description: |
                        Approximate location parameters for the search.
                      properties:
                        type:
                          type: string
                          description: >
                            The type of location approximation. Always `approximate`.
                          enum:
                            - approximate
                          x-stainless-const: true
                        approximate:
                          $ref: "#/components/schemas/WebSearchLocation"
                    search_context_size:
                      $ref: "#/components/schemas/WebSearchContextSize"
                top_logprobs:
                  description: >
                    An integer between 0 and 20 specifying the number of most likely
                    tokens to

                    return at each token position, each with an associated log
                    probability.

                    `logprobs` must be set to `true` if this parameter is used.
                  type: integer
                  minimum: 0
                  maximum: 20
                  nullable: true
                response_format:
                  description: >
                    An object specifying the format that the model must output.


                    Setting to `{ "type": "json_schema", "json_schema": {...} }`
                    enables

                    Structured Outputs which ensures the model will match your
                    supplied JSON

                    schema. Learn more in the [Structured Outputs

                    guide](/docs/guides/structured-outputs).


                    Setting to `{ "type": "json_object" }` enables the older JSON
                    mode, which

                    ensures the message the model generates is valid JSON. Using
                    `json_schema`

                    is preferred for models that support it.
                  oneOf:
                    - $ref: "#/components/schemas/ResponseFormatText"
                    - $ref: "#/components/schemas/ResponseFormatJsonSchema"
                    - $ref: "#/components/schemas/ResponseFormatJsonObject"
                  x-oaiExpandable: true
                service_tier:
                  description: >
                    Specifies the latency tier to use for processing the request.
                    This parameter is relevant for customers subscribed to the scale
                    tier service:
                      - If set to 'auto', and the Project is Scale tier enabled, the system
                        will utilize scale tier credits until they are exhausted.
                      - If set to 'auto', and the Project is not Scale tier enabled, the request will be processed using the default service tier with a lower uptime SLA and no latency guarentee.
                      - If set to 'default', the request will be processed using the default service tier with a lower uptime SLA and no latency guarentee.
                      - When not set, the default behavior is 'auto'.

                      When this parameter is set, the response body will include the `service_tier` utilized.
                  type: string
                  enum:
                    - auto
                    - default
                  nullable: true
                  default: auto
                audio:
                  type: object
                  nullable: true
                  description: >
                    Parameters for audio output. Required when audio output is
                    requested with

                    `modalities: ["audio"]`. [Learn more](/docs/guides/audio).
                  required:
                    - voice
                    - format
                  x-oaiExpandable: true
                  properties:
                    voice:
                      type: string
                      enum:
                        - alloy
                        - ash
                        - ballad
                        - coral
                        - echo
                        - sage
                        - shimmer
                        - verse
                      description: >
                        The voice the model uses to respond. Supported voices are

                        `alloy`, `ash`, `ballad`, `coral`, `echo`, `sage`, and
                        `shimmer`.
                    format:
                      type: string
                      enum:
                        - wav
                        - mp3
                        - flac
                        - opus
                        - pcm16
                      description: >
                        Specifies the output audio format. Must be one of `wav`,
                        `mp3`, `flac`,

                        `opus`, or `pcm16`.
                store:
                  type: boolean
                  default: false
                  nullable: true
                  description: >
                    Whether or not to store the output of this chat completion
                    request for

                    use in our [model distillation](/docs/guides/distillation) or

                    [evals](/docs/guides/evals) products.
                stream:
                  description: >
                    If set to true, the model response data will be streamed to the
                    client

                    as it is generated using [server-sent
                    events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events#Event_stream_format).

                    See the [Streaming section
                    below](/docs/api-reference/chat/streaming)

                    for more information, along with the [streaming
                    responses](/docs/guides/streaming-responses)

                    guide for more information on how to handle the streaming
                    events.
                  type: boolean
                  nullable: true
                  default: false
                stop:
                  $ref: "#/components/schemas/StopConfiguration"
                logit_bias:
                  type: object
                  x-oaiTypeLabel: map
                  default: null
                  nullable: true
                  additionalProperties:
                    type: integer
                  description: >
                    Modify the likelihood of specified tokens appearing in the
                    completion.


                    Accepts a JSON object that maps tokens (specified by their token
                    ID in the

                    tokenizer) to an associated bias value from -100 to 100.
                    Mathematically,

                    the bias is added to the logits generated by the model prior to
                    sampling.

                    The exact effect will vary per model, but values between -1 and
                    1 should

                    decrease or increase likelihood of selection; values like -100
                    or 100

                    should result in a ban or exclusive selection of the relevant
                    token.
                logprobs:
                  description: >
                    Whether to return log probabilities of the output tokens or not.
                    If true,

                    returns the log probabilities of each output token returned in
                    the

                    `content` of `message`.
                  type: boolean
                  default: false
                  nullable: true
                max_tokens:
                  description: >
                    The maximum number of [tokens](/tokenizer) that can be generated
                    in the

                    chat completion. This value can be used to control

                    [costs](https://openai.com/api/pricing/) for text generated via
                    API.


                    This value is now deprecated in favor of
                    `max_completion_tokens`, and is

                    not compatible with [o1 series models](/docs/guides/reasoning).
                  type: integer
                  nullable: true
                  deprecated: true
                n:
                  type: integer
                  minimum: 1
                  maximum: 128
                  default: 1
                  example: 1
                  nullable: true
                  description: How many chat completion choices to generate for each input
                    message. Note that you will be charged based on the number of
                    generated tokens across all of the choices. Keep `n` as `1` to
                    minimize costs.
                prediction:
                  nullable: true
                  x-oaiExpandable: true
                  description: >
                    Configuration for a [Predicted
                    Output](/docs/guides/predicted-outputs),

                    which can greatly improve response times when large parts of the
                    model

                    response are known ahead of time. This is most common when you
                    are

                    regenerating a file with only minor changes to most of the
                    content.
                  oneOf:
                    - $ref: "#/components/schemas/PredictionContent"
                seed:
                  type: integer
                  minimum: -9223372036854776000
                  maximum: 9223372036854776000
                  nullable: true
                  description: >
                    This feature is in Beta.

                    If specified, our system will make a best effort to sample
                    deterministically, such that repeated requests with the same
                    `seed` and parameters should return the same result.

                    Determinism is not guaranteed, and you should refer to the
                    `system_fingerprint` response parameter to monitor changes in
                    the backend.
                  x-oaiMeta:
                    beta: true
                stream_options:
                  $ref: "#/components/schemas/ChatCompletionStreamOptions"
                tools:
                  type: array
                  description: >
                    A list of tools the model may call. Currently, only functions
                    are supported as a tool. Use this to provide a list of functions
                    the model may generate JSON inputs for. A max of 128 functions
                    are supported.
                  items:
                    $ref: "#/components/schemas/ChatCompletionTool"
                tool_choice:
                  $ref: "#/components/schemas/ChatCompletionToolChoiceOption"
                parallel_tool_calls:
                  $ref: "#/components/schemas/ParallelToolCalls"
                function_call:
                  deprecated: true
                  description: >
                    Deprecated in favor of `tool_choice`.


                    Controls which (if any) function is called by the model.


                    `none` means the model will not call a function and instead
                    generates a

                    message.


                    `auto` means the model can pick between generating a message or
                    calling a

                    function.


                    Specifying a particular function via `{"name": "my_function"}`
                    forces the

                    model to call that function.


                    `none` is the default when no functions are present. `auto` is
                    the default

                    if functions are present.
                  oneOf:
                    - type: string
                      description: >
                        `none` means the model will not call a function and instead
                        generates a message. `auto` means the model can pick between
                        generating a message or calling a function.
                      enum:
                        - none
                        - auto
                    - $ref: "#/components/schemas/ChatCompletionFunctionCallOption"
                  x-oaiExpandable: true
                functions:
                  deprecated: true
                  description: |
                    Deprecated in favor of `tools`.

                    A list of functions the model may generate JSON inputs for.
                  type: array
                  minItems: 1
                  maxItems: 128
                  items:
                    $ref: "#/components/schemas/ChatCompletionFunctions"
              required:
                - model
                - messages
        """)
        |> List.first()

      expected = %{
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
                name: "audio",
                type:
                  {:object,
                   %{
                     "format" => {:enum, [:wav, :mp3, :flac, :opus, :pcm16]},
                     "voice" =>
                       {:enum, [:alloy, :ash, :ballad, :coral, :echo, :sage, :shimmer, :verse]}
                   }},
                description:
                  "Parameters for audio output. Required when audio output is requested with\n`modalities: [\"audio\"]`. [Learn more](/docs/guides/audio).\n",
                example: ""
              },
              %{
                name: "frequency_penalty",
                type: "number",
                description:
                  "Number between -2.0 and 2.0. Positive values penalize new tokens based on\ntheir existing frequency in the text so far, decreasing the model's\nlikelihood to repeat the same line verbatim.\n",
                example: ""
              },
              %{
                name: "function_call",
                type:
                  {:oneOf, [enum: [:none, :auto], component: "ChatCompletionFunctionCallOption"]},
                description:
                  "Deprecated in favor of `tool_choice`.\n\nControls which (if any) function is called by the model.\n\n`none` means the model will not call a function and instead generates a\nmessage.\n\n`auto` means the model can pick between generating a message or calling a\nfunction.\n\nSpecifying a particular function via `{\"name\": \"my_function\"}` forces the\nmodel to call that function.\n\n`none` is the default when no functions are present. `auto` is the default\nif functions are present.\n",
                required: false
              },
              %{
                name: "functions",
                type: {:array, {:component, "ChatCompletionFunctions"}},
                description:
                  "Deprecated in favor of `tools`.\n\nA list of functions the model may generate JSON inputs for.\n",
                example: ""
              },
              %{
                name: "logit_bias",
                type: "object",
                description:
                  "Modify the likelihood of specified tokens appearing in the completion.\n\nAccepts a JSON object that maps tokens (specified by their token ID in the\ntokenizer) to an associated bias value from -100 to 100. Mathematically,\nthe bias is added to the logits generated by the model prior to sampling.\nThe exact effect will vary per model, but values between -1 and 1 should\ndecrease or increase likelihood of selection; values like -100 or 100\nshould result in a ban or exclusive selection of the relevant token.\n",
                example: ""
              },
              %{
                name: "logprobs",
                type: "boolean",
                description:
                  "Whether to return log probabilities of the output tokens or not. If true,\nreturns the log probabilities of each output token returned in the\n`content` of `message`.\n",
                example: ""
              },
              %{
                name: "max_completion_tokens",
                type: "integer",
                description:
                  "An upper bound for the number of tokens that can be generated for a completion, including visible output tokens and [reasoning tokens](/docs/guides/reasoning).\n",
                example: ""
              },
              %{
                name: "max_tokens",
                type: "integer",
                description:
                  "The maximum number of [tokens](/tokenizer) that can be generated in the\nchat completion. This value can be used to control\n[costs](https://openai.com/api/pricing/) for text generated via API.\n\nThis value is now deprecated in favor of `max_completion_tokens`, and is\nnot compatible with [o1 series models](/docs/guides/reasoning).\n",
                example: ""
              },
              %{
                name: "modalities",
                type: {:component, "ResponseModalities"},
                description: "",
                example: ""
              },
              %{
                name: "n",
                type: "integer",
                description:
                  "How many chat completion choices to generate for each input message. Note that you will be charged based on the number of generated tokens across all of the choices. Keep `n` as `1` to minimize costs.",
                example: 1
              },
              %{
                name: "parallel_tool_calls",
                type: {:component, "ParallelToolCalls"},
                description: "",
                example: ""
              },
              %{
                name: "prediction",
                type: {:oneOf, [component: "PredictionContent"]},
                description:
                  "Configuration for a [Predicted Output](/docs/guides/predicted-outputs),\nwhich can greatly improve response times when large parts of the model\nresponse are known ahead of time. This is most common when you are\nregenerating a file with only minor changes to most of the content.\n",
                required: false
              },
              %{
                name: "presence_penalty",
                type: "number",
                description:
                  "Number between -2.0 and 2.0. Positive values penalize new tokens based on\nwhether they appear in the text so far, increasing the model's likelihood\nto talk about new topics.\n",
                example: ""
              },
              %{
                name: "reasoning_effort",
                type: {:component, "ReasoningEffort"},
                description: "",
                example: ""
              },
              %{
                name: "response_format",
                type:
                  {:oneOf,
                   [
                     component: "ResponseFormatText",
                     component: "ResponseFormatJsonSchema",
                     component: "ResponseFormatJsonObject"
                   ]},
                description:
                  "An object specifying the format that the model must output.\n\nSetting to `{ \"type\": \"json_schema\", \"json_schema\": {...} }` enables\nStructured Outputs which ensures the model will match your supplied JSON\nschema. Learn more in the [Structured Outputs\nguide](/docs/guides/structured-outputs).\n\nSetting to `{ \"type\": \"json_object\" }` enables the older JSON mode, which\nensures the message the model generates is valid JSON. Using `json_schema`\nis preferred for models that support it.\n",
                required: false
              },
              %{
                name: "seed",
                type: "integer",
                description:
                  "This feature is in Beta.\nIf specified, our system will make a best effort to sample deterministically, such that repeated requests with the same `seed` and parameters should return the same result.\nDeterminism is not guaranteed, and you should refer to the `system_fingerprint` response parameter to monitor changes in the backend.\n",
                example: ""
              },
              %{
                name: "service_tier",
                type: {:enum, [:auto, :default]},
                description:
                  "Specifies the latency tier to use for processing the request. This parameter is relevant for customers subscribed to the scale tier service:\n  - If set to 'auto', and the Project is Scale tier enabled, the system\n    will utilize scale tier credits until they are exhausted.\n  - If set to 'auto', and the Project is not Scale tier enabled, the request will be processed using the default service tier with a lower uptime SLA and no latency guarentee.\n  - If set to 'default', the request will be processed using the default service tier with a lower uptime SLA and no latency guarentee.\n  - When not set, the default behavior is 'auto'.\n\n  When this parameter is set, the response body will include the `service_tier` utilized.\n",
                example: ""
              },
              %{
                name: "stop",
                type: {:component, "StopConfiguration"},
                description: "",
                example: ""
              },
              %{
                name: "store",
                type: "boolean",
                description:
                  "Whether or not to store the output of this chat completion request for\nuse in our [model distillation](/docs/guides/distillation) or\n[evals](/docs/guides/evals) products.\n",
                example: ""
              },
              %{
                name: "stream",
                type: "boolean",
                description:
                  "If set to true, the model response data will be streamed to the client\nas it is generated using [server-sent events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events#Event_stream_format).\nSee the [Streaming section below](/docs/api-reference/chat/streaming)\nfor more information, along with the [streaming responses](/docs/guides/streaming-responses)\nguide for more information on how to handle the streaming events.\n",
                example: ""
              },
              %{
                name: "stream_options",
                type: {:component, "ChatCompletionStreamOptions"},
                description: "",
                example: ""
              },
              %{
                name: "tool_choice",
                type: {:component, "ChatCompletionToolChoiceOption"},
                description: "",
                example: ""
              },
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
              },
              %{
                name: "web_search_options",
                type:
                  {:object,
                   %{
                     "search_context_size" => {:component, "WebSearchContextSize"},
                     "user_location" =>
                       {:object,
                        %{
                          "approximate" => {:component, "WebSearchLocation"},
                          "type" => {:enum, [:approximate]}
                        }}
                   }},
                description:
                  "This tool searches the web for relevant results to use in a response.\nLearn more about the [web search tool](/docs/guides/tools-web-search?api-mode=chat).\n",
                example: ""
              }
            ]
          }
        ],
        required_props: [],
        optional_props: [],
        required_prop_keys: ["model", "messages"]
      }

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)
      assert parsed == expected
    end

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
        kind: :component,
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

    test "parse schema with oneOf refs" do
      test_schema =
        ~S"
      oneOf:
        - $ref: \"#/components/schemas/ChatCompletionRequestMessageContentPartText\"
        - $ref: \"#/components/schemas/ChatCompletionRequestMessageContentPartImage\"
      x-oaiExpandable: true
    "
        |> YamlElixir.read_all_from_string!()
        |> List.first()

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == %{
               kind: :oneOf,
               components: [
                 component: "ChatCompletionRequestMessageContentPartText",
                 component: "ChatCompletionRequestMessageContentPartImage"
               ],
               optional_props: [],
               required_props: [],
               description: ""
             }
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
        kind: :component,
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
        kind: :component,
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

    test "schema with enum" do
      test_schema =
        YamlElixir.read_all_from_string!(~S"
      properties:
        model:
          type: string
          enum:
            - o3-mini
            - o3-mini-2025-01-31
            - o1
            - o1-2024-12-17
            - gpt-4o
            - gpt-4o-2024-11-20
            - gpt-4o-2024-08-06
            - gpt-4o-2024-05-13
            - gpt-4o-mini
            - gpt-4o-mini-2024-07-18
            - gpt-4-turbo
          description: The model to use for generating completions
      required:
        - model
        ")
        |> List.first()

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == %{
               description: "",
               kind: :component,
               optional_props: [],
               required_props: [
                 %{
                   description: "The model to use for generating completions",
                   example: "",
                   name: "model",
                   type:
                     {:enum,
                      [
                        :"o3-mini",
                        :"o3-mini-2025-01-31",
                        :o1,
                        :"o1-2024-12-17",
                        :"gpt-4o",
                        :"gpt-4o-2024-11-20",
                        :"gpt-4o-2024-08-06",
                        :"gpt-4o-2024-05-13",
                        :"gpt-4o-mini",
                        :"gpt-4o-mini-2024-07-18",
                        :"gpt-4-turbo"
                      ]}
                 }
               ]
             }
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
        kind: :component,
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
        kind: :component,
        optional_props: [],
        required_props: [],
        description:
          "The parameters the functions accepts, described as a JSON Schema object. See the [guide](/docs/guides/gpt/function-calling) for examples, and the [JSON Schema reference](https://json-schema.org/understanding-json-schema/) for documentation about the format."
      }

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == expected
    end

    test "schema with anyOf choice" do
      test_schema =
        YamlElixir.read_all_from_string!(~S"
      type: object
      properties:
        model:
          description: ID of the model to use. You can use the `text-davinci-edit-001` or `code-davinci-edit-001` model with this endpoint.
          type: string
          example: \"text-davinci-edit-001\"
          anyOf:
            - type: string
            - type: string
              enum: [\"text-davinci-edit-001\",\"code-davinci-edit-001\"]
        ")
        |> List.first()

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == %{
               description: "",
               kind: :component,
               optional_props: [
                 %{
                   name: "model",
                   required: false,
                   type:
                     {:anyOf,
                      [
                        "string",
                        {:enum, [:"text-davinci-edit-001", :"code-davinci-edit-001"]}
                      ]},
                   description:
                     "ID of the model to use. You can use the `text-davinci-edit-001` or `code-davinci-edit-001` model with this endpoint."
                 }
               ],
               required_props: []
             }
    end

    test "schema with oneOf choice" do
      test_schema =
        YamlElixir.read_all_from_string!(~S"
      type: object
      properties:
        model:
          description: ID of the model to use. You can use the `text-davinci-edit-001` or `code-davinci-edit-001` model with this endpoint.
          type: string
          example: \"text-davinci-edit-001\"
          oneOf:
            - type: string
            - type: string
              enum: [\"text-davinci-edit-001\",\"code-davinci-edit-001\"]
        ")
        |> List.first()

      parsed = ExOpenAI.Codegen.parse_component_schema(test_schema)

      assert parsed == %{
               description: "",
               kind: :component,
               optional_props: [
                 %{
                   name: "model",
                   required: false,
                   type:
                     {:oneOf,
                      [
                        "string",
                        {:enum, [:"text-davinci-edit-001", :"code-davinci-edit-001"]}
                      ]},
                   description:
                     "ID of the model to use. You can use the `text-davinci-edit-001` or `code-davinci-edit-001` model with this endpoint."
                 }
               ],
               required_props: []
             }
    end
  end
end
