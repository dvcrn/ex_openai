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

      assert ExOpenAI.Codegen.type_to_spec("pid") == {:pid, [], []}
      assert ExOpenAI.Codegen.type_to_spec(:pid) == {:pid, [], []}

      assert ExOpenAI.Codegen.type_to_spec("string") ==
               {{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []}

      # bitstrings are either just bitstring, or a tuple of {filename, bitstring}
      assert ExOpenAI.Codegen.type_to_spec("bitstring") == {
               :|,
               [],
               [
                 {:bitstring, [], []},
                 {{{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []},
                  {:bitstring, [], []}}
               ]
             }

      assert ExOpenAI.Codegen.type_to_spec(:bitstring) == {
               :|,
               [],
               [
                 {:bitstring, [], []},
                 {{{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []},
                  {:bitstring, [], []}}
               ]
             }
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

    test "oneOf" do
      assert ExOpenAI.Codegen.type_to_spec({:oneOf, [{:enum, [:auto]}, "integer"]}) ==
               {:|, [], [{:integer, [], []}, :auto]}
    end

    test "anyOf" do
      assert ExOpenAI.Codegen.type_to_spec({:anyOf, [{:enum, [:auto]}, "integer"]}) ==
               {:|, [], [{:integer, [], []}, :auto]}
    end

    test "allOf" do
      assert ExOpenAI.Codegen.type_to_spec(
               {:allOf, [{:component, "AssistantsApiResponseFormatOption"}, "string"]}
             ) ==
               {:|, [],
                [
                  {{:., [], [{:__aliases__, [alias: false], [:String]}, :t]}, [], []},
                  {{:., [],
                    [
                      {:__aliases__, [alias: false],
                       [:ExOpenAI, :Components, :AssistantsApiResponseFormatOption]},
                      :t
                    ]}, [], []}
                ]}
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

      IO.puts("---------------------------------------------------")
      IO.puts("---------------------------------------------------")
      IO.puts("---------------------------------------------------")
      IO.puts("---------------------------------------------------")
      IO.puts("---------------------------------------------------")

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

    test "oneOf" do
      assert ExOpenAI.Codegen.parse_type(%{
               "default" => "auto",
               "description" =>
                 "The number of epochs to train the model for. An epoch refers to one\nfull cycle through the training dataset.\n",
               "oneOf" => [
                 %{"enum" => ["auto"], "type" => "string"},
                 %{"maximum" => 50, "minimum" => 1, "type" => "integer"}
               ]
             }) == {:oneOf, [{:enum, [:auto]}, "integer"]}
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
        group: "foo",
        method: :get,
        name: "mypath",
        response_type: :string,
        summary: "some summary"
      }

      assert ExOpenAI.Codegen.parse_path("/foo/${engine_id}", handler_schema, %{}) == expected
    end

    test "path with 'query in'" do
      handler_schema =
        ~S"""
        post:
          operationId: createRun
          tags:
            - Assistants
          summary: Create a run.
          parameters:
            - in: path
              name: thread_id
              required: true
              schema:
                type: string
              description: The ID of the thread to run.
            - name: include[]
              in: query
              description: >
                A list of additional fields to include in the response. Currently
                the only supported value is
                `step_details.tool_calls[*].file_search.results[*].content` to fetch
                the file search result content.


                See the [file search tool
                documentation](/docs/assistants/tools/file-search#customizing-file-search-settings)
                for more information.
              schema:
                type: array
                items:
                  type: string
                  enum:
                    - step_details.tool_calls[*].file_search.results[*].content
          requestBody:
            required: true
            content:
              application/json:
                schema:
                  $ref: "#/components/schemas/CreateRunRequest"
          responses:
            "200":
              description: OK
              content:
                application/json:
                  schema:
                    $ref: "#/components/schemas/RunObject"
          x-oaiMeta:
            name: Create run
            group: threads
            beta: true
            returns: A [run](/docs/api-reference/runs/object) object.
            examples:
              - title: Default
                request:
                  curl: |
                    curl https://api.openai.com/v1/threads/thread_abc123/runs \
                      -H "Authorization: Bearer $OPENAI_API_KEY" \
                      -H "Content-Type: application/json" \
                      -H "OpenAI-Beta: assistants=v2" \
                      -d '{
                        "assistant_id": "asst_abc123"
                      }'
                  python: |
                    from openai import OpenAI
                    client = OpenAI()

                    run = client.beta.threads.runs.create(
                      thread_id="thread_abc123",
                      assistant_id="asst_abc123"
                    )

                    print(run)
                  node.js: |
                    import OpenAI from "openai";

                    const openai = new OpenAI();

                    async function main() {
                      const run = await openai.beta.threads.runs.create(
                        "thread_abc123",
                        { assistant_id: "asst_abc123" }
                      );

                      console.log(run);
                    }

                    main();
                response: |
                  {
                    "id": "run_abc123",
                    "object": "thread.run",
                    "created_at": 1699063290,
                    "assistant_id": "asst_abc123",
                    "thread_id": "thread_abc123",
                    "status": "queued",
                    "started_at": 1699063290,
                    "expires_at": null,
                    "cancelled_at": null,
                    "failed_at": null,
                    "completed_at": 1699063291,
                    "last_error": null,
                    "model": "gpt-4o",
                    "instructions": null,
                    "incomplete_details": null,
                    "tools": [
                      {
                        "type": "code_interpreter"
                      }
                    ],
                    "metadata": {},
                    "usage": null,
                    "temperature": 1.0,
                    "top_p": 1.0,
                    "max_prompt_tokens": 1000,
                    "max_completion_tokens": 1000,
                    "truncation_strategy": {
                      "type": "auto",
                      "last_messages": null
                    },
                    "response_format": "auto",
                    "tool_choice": "auto",
                    "parallel_tool_calls": true
                  }
              - title: Streaming
                request:
                  curl: |
                    curl https://api.openai.com/v1/threads/thread_123/runs \
                      -H "Authorization: Bearer $OPENAI_API_KEY" \
                      -H "Content-Type: application/json" \
                      -H "OpenAI-Beta: assistants=v2" \
                      -d '{
                        "assistant_id": "asst_123",
                        "stream": true
                      }'
                  python: |
                    from openai import OpenAI
                    client = OpenAI()

                    stream = client.beta.threads.runs.create(
                      thread_id="thread_123",
                      assistant_id="asst_123",
                      stream=True
                    )

                    for event in stream:
                      print(event)
                  node.js: |
                    import OpenAI from "openai";

                    const openai = new OpenAI();

                    async function main() {
                      const stream = await openai.beta.threads.runs.create(
                        "thread_123",
                        { assistant_id: "asst_123", stream: true }
                      );

                      for await (const event of stream) {
                        console.log(event);
                      }
                    }

                    main();
                response: >
                  event: thread.run.created

                  data:
                  {"id":"run_123","object":"thread.run","created_at":1710330640,"assistant_id":"asst_123","thread_id":"thread_123","status":"queued","started_at":null,"expires_at":1710331240,"cancelled_at":null,"failed_at":null,"completed_at":null,"required_action":null,"last_error":null,"model":"gpt-4o","instructions":null,"tools":[],"metadata":{},"temperature":1.0,"top_p":1.0,"max_completion_tokens":null,"max_prompt_tokens":null,"truncation_strategy":{"type":"auto","last_messages":null},"incomplete_details":null,"usage":null,"response_format":"auto","tool_choice":"auto","parallel_tool_calls":true}}


                  event: thread.run.queued

                  data:
                  {"id":"run_123","object":"thread.run","created_at":1710330640,"assistant_id":"asst_123","thread_id":"thread_123","status":"queued","started_at":null,"expires_at":1710331240,"cancelled_at":null,"failed_at":null,"completed_at":null,"required_action":null,"last_error":null,"model":"gpt-4o","instructions":null,"tools":[],"metadata":{},"temperature":1.0,"top_p":1.0,"max_completion_tokens":null,"max_prompt_tokens":null,"truncation_strategy":{"type":"auto","last_messages":null},"incomplete_details":null,"usage":null,"response_format":"auto","tool_choice":"auto","parallel_tool_calls":true}}


                  event: thread.run.in_progress

                  data:
                  {"id":"run_123","object":"thread.run","created_at":1710330640,"assistant_id":"asst_123","thread_id":"thread_123","status":"in_progress","started_at":1710330641,"expires_at":1710331240,"cancelled_at":null,"failed_at":null,"completed_at":null,"required_action":null,"last_error":null,"model":"gpt-4o","instructions":null,"tools":[],"metadata":{},"temperature":1.0,"top_p":1.0,"max_completion_tokens":null,"max_prompt_tokens":null,"truncation_strategy":{"type":"auto","last_messages":null},"incomplete_details":null,"usage":null,"response_format":"auto","tool_choice":"auto","parallel_tool_calls":true}}


                  event: thread.run.step.created

                  data:
                  {"id":"step_001","object":"thread.run.step","created_at":1710330641,"run_id":"run_123","assistant_id":"asst_123","thread_id":"thread_123","type":"message_creation","status":"in_progress","cancelled_at":null,"completed_at":null,"expires_at":1710331240,"failed_at":null,"last_error":null,"step_details":{"type":"message_creation","message_creation":{"message_id":"msg_001"}},"usage":null}


                  event: thread.run.step.in_progress

                  data:
                  {"id":"step_001","object":"thread.run.step","created_at":1710330641,"run_id":"run_123","assistant_id":"asst_123","thread_id":"thread_123","type":"message_creation","status":"in_progress","cancelled_at":null,"completed_at":null,"expires_at":1710331240,"failed_at":null,"last_error":null,"step_details":{"type":"message_creation","message_creation":{"message_id":"msg_001"}},"usage":null}


                  event: thread.message.created

                  data:
                  {"id":"msg_001","object":"thread.message","created_at":1710330641,"assistant_id":"asst_123","thread_id":"thread_123","run_id":"run_123","status":"in_progress","incomplete_details":null,"incomplete_at":null,"completed_at":null,"role":"assistant","content":[],"metadata":{}}


                  event: thread.message.in_progress

                  data:
                  {"id":"msg_001","object":"thread.message","created_at":1710330641,"assistant_id":"asst_123","thread_id":"thread_123","run_id":"run_123","status":"in_progress","incomplete_details":null,"incomplete_at":null,"completed_at":null,"role":"assistant","content":[],"metadata":{}}


                  event: thread.message.delta

                  data:
                  {"id":"msg_001","object":"thread.message.delta","delta":{"content":[{"index":0,"type":"text","text":{"value":"Hello","annotations":[]}}]}}


                  ...


                  event: thread.message.delta

                  data:
                  {"id":"msg_001","object":"thread.message.delta","delta":{"content":[{"index":0,"type":"text","text":{"value":"
                  today"}}]}}


                  event: thread.message.delta

                  data:
                  {"id":"msg_001","object":"thread.message.delta","delta":{"content":[{"index":0,"type":"text","text":{"value":"?"}}]}}


                  event: thread.message.completed

                  data:
                  {"id":"msg_001","object":"thread.message","created_at":1710330641,"assistant_id":"asst_123","thread_id":"thread_123","run_id":"run_123","status":"completed","incomplete_details":null,"incomplete_at":null,"completed_at":1710330642,"role":"assistant","content":[{"type":"text","text":{"value":"Hello!
                  How can I assist you today?","annotations":[]}}],"metadata":{}}


                  event: thread.run.step.completed

                  data:
                  {"id":"step_001","object":"thread.run.step","created_at":1710330641,"run_id":"run_123","assistant_id":"asst_123","thread_id":"thread_123","type":"message_creation","status":"completed","cancelled_at":null,"completed_at":1710330642,"expires_at":1710331240,"failed_at":null,"last_error":null,"step_details":{"type":"message_creation","message_creation":{"message_id":"msg_001"}},"usage":{"prompt_tokens":20,"completion_tokens":11,"total_tokens":31}}


                  event: thread.run.completed

                  data:
                  {"id":"run_123","object":"thread.run","created_at":1710330640,"assistant_id":"asst_123","thread_id":"thread_123","status":"completed","started_at":1710330641,"expires_at":null,"cancelled_at":null,"failed_at":null,"completed_at":1710330642,"required_action":null,"last_error":null,"model":"gpt-4o","instructions":null,"tools":[],"metadata":{},"temperature":1.0,"top_p":1.0,"max_completion_tokens":null,"max_prompt_tokens":null,"truncation_strategy":{"type":"auto","last_messages":null},"incomplete_details":null,"usage":{"prompt_tokens":20,"completion_tokens":11,"total_tokens":31},"response_format":"auto","tool_choice":"auto","parallel_tool_calls":true}}


                  event: done

                  data: [DONE]
              - title: Streaming with Functions
                request:
                  curl: >
                    curl https://api.openai.com/v1/threads/thread_abc123/runs \
                      -H "Authorization: Bearer $OPENAI_API_KEY" \
                      -H "Content-Type: application/json" \
                      -H "OpenAI-Beta: assistants=v2" \
                      -d '{
                        "assistant_id": "asst_abc123",
                        "tools": [
                          {
                            "type": "function",
                            "function": {
                              "name": "get_current_weather",
                              "description": "Get the current weather in a given location",
                              "parameters": {
                                "type": "object",
                                "properties": {
                                  "location": {
                                    "type": "string",
                                    "description": "The city and state, e.g. San Francisco, CA"
                                  },
                                  "unit": {
                                    "type": "string",
                                    "enum": ["celsius", "fahrenheit"]
                                  }
                                },
                                "required": ["location"]
                              }
                            }
                          }
                        ],
                        "stream": true
                      }'
                  python: >
                    from openai import OpenAI

                    client = OpenAI()


                    tools = [
                      {
                        "type": "function",
                        "function": {
                          "name": "get_current_weather",
                          "description": "Get the current weather in a given location",
                          "parameters": {
                            "type": "object",
                            "properties": {
                              "location": {
                                "type": "string",
                                "description": "The city and state, e.g. San Francisco, CA",
                              },
                              "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]},
                            },
                            "required": ["location"],
                          },
                        }
                      }
                    ]


                    stream = client.beta.threads.runs.create(
                      thread_id="thread_abc123",
                      assistant_id="asst_abc123",
                      tools=tools,
                      stream=True
                    )


                    for event in stream:
                      print(event)
                  node.js: >
                    import OpenAI from "openai";


                    const openai = new OpenAI();


                    const tools = [
                        {
                          "type": "function",
                          "function": {
                            "name": "get_current_weather",
                            "description": "Get the current weather in a given location",
                            "parameters": {
                              "type": "object",
                              "properties": {
                                "location": {
                                  "type": "string",
                                  "description": "The city and state, e.g. San Francisco, CA",
                                },
                                "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]},
                              },
                              "required": ["location"],
                            },
                          }
                        }
                    ];


                    async function main() {
                      const stream = await openai.beta.threads.runs.create(
                        "thread_abc123",
                        {
                          assistant_id: "asst_abc123",
                          tools: tools,
                          stream: true
                        }
                      );

                      for await (const event of stream) {
                        console.log(event);
                      }
                    }


                    main();
                response: >
                  event: thread.run.created

                  data:
                  {"id":"run_123","object":"thread.run","created_at":1710348075,"assistant_id":"asst_123","thread_id":"thread_123","status":"queued","started_at":null,"expires_at":1710348675,"cancelled_at":null,"failed_at":null,"completed_at":null,"required_action":null,"last_error":null,"model":"gpt-4o","instructions":null,"tools":[],"metadata":{},"temperature":1.0,"top_p":1.0,"max_completion_tokens":null,"max_prompt_tokens":null,"truncation_strategy":{"type":"auto","last_messages":null},"incomplete_details":null,"usage":null,"response_format":"auto","tool_choice":"auto","parallel_tool_calls":true}}


                  event: thread.run.queued

                  data:
                  {"id":"run_123","object":"thread.run","created_at":1710348075,"assistant_id":"asst_123","thread_id":"thread_123","status":"queued","started_at":null,"expires_at":1710348675,"cancelled_at":null,"failed_at":null,"completed_at":null,"required_action":null,"last_error":null,"model":"gpt-4o","instructions":null,"tools":[],"metadata":{},"temperature":1.0,"top_p":1.0,"max_completion_tokens":null,"max_prompt_tokens":null,"truncation_strategy":{"type":"auto","last_messages":null},"incomplete_details":null,"usage":null,"response_format":"auto","tool_choice":"auto","parallel_tool_calls":true}}


                  event: thread.run.in_progress

                  data:
                  {"id":"run_123","object":"thread.run","created_at":1710348075,"assistant_id":"asst_123","thread_id":"thread_123","status":"in_progress","started_at":1710348075,"expires_at":1710348675,"cancelled_at":null,"failed_at":null,"completed_at":null,"required_action":null,"last_error":null,"model":"gpt-4o","instructions":null,"tools":[],"metadata":{},"temperature":1.0,"top_p":1.0,"max_completion_tokens":null,"max_prompt_tokens":null,"truncation_strategy":{"type":"auto","last_messages":null},"incomplete_details":null,"usage":null,"response_format":"auto","tool_choice":"auto","parallel_tool_calls":true}}


                  event: thread.run.step.created

                  data:
                  {"id":"step_001","object":"thread.run.step","created_at":1710348076,"run_id":"run_123","assistant_id":"asst_123","thread_id":"thread_123","type":"message_creation","status":"in_progress","cancelled_at":null,"completed_at":null,"expires_at":1710348675,"failed_at":null,"last_error":null,"step_details":{"type":"message_creation","message_creation":{"message_id":"msg_001"}},"usage":null}


                  event: thread.run.step.in_progress

                  data:
                  {"id":"step_001","object":"thread.run.step","created_at":1710348076,"run_id":"run_123","assistant_id":"asst_123","thread_id":"thread_123","type":"message_creation","status":"in_progress","cancelled_at":null,"completed_at":null,"expires_at":1710348675,"failed_at":null,"last_error":null,"step_details":{"type":"message_creation","message_creation":{"message_id":"msg_001"}},"usage":null}


                  event: thread.message.created

                  data:
                  {"id":"msg_001","object":"thread.message","created_at":1710348076,"assistant_id":"asst_123","thread_id":"thread_123","run_id":"run_123","status":"in_progress","incomplete_details":null,"incomplete_at":null,"completed_at":null,"role":"assistant","content":[],"metadata":{}}


                  event: thread.message.in_progress

                  data:
                  {"id":"msg_001","object":"thread.message","created_at":1710348076,"assistant_id":"asst_123","thread_id":"thread_123","run_id":"run_123","status":"in_progress","incomplete_details":null,"incomplete_at":null,"completed_at":null,"role":"assistant","content":[],"metadata":{}}


                  event: thread.message.delta

                  data:
                  {"id":"msg_001","object":"thread.message.delta","delta":{"content":[{"index":0,"type":"text","text":{"value":"Hello","annotations":[]}}]}}


                  ...


                  event: thread.message.delta

                  data:
                  {"id":"msg_001","object":"thread.message.delta","delta":{"content":[{"index":0,"type":"text","text":{"value":"
                  today"}}]}}


                  event: thread.message.delta

                  data:
                  {"id":"msg_001","object":"thread.message.delta","delta":{"content":[{"index":0,"type":"text","text":{"value":"?"}}]}}


                  event: thread.message.completed

                  data:
                  {"id":"msg_001","object":"thread.message","created_at":1710348076,"assistant_id":"asst_123","thread_id":"thread_123","run_id":"run_123","status":"completed","incomplete_details":null,"incomplete_at":null,"completed_at":1710348077,"role":"assistant","content":[{"type":"text","text":{"value":"Hello!
                  How can I assist you today?","annotations":[]}}],"metadata":{}}


                  event: thread.run.step.completed

                  data:
                  {"id":"step_001","object":"thread.run.step","created_at":1710348076,"run_id":"run_123","assistant_id":"asst_123","thread_id":"thread_123","type":"message_creation","status":"completed","cancelled_at":null,"completed_at":1710348077,"expires_at":1710348675,"failed_at":null,"last_error":null,"step_details":{"type":"message_creation","message_creation":{"message_id":"msg_001"}},"usage":{"prompt_tokens":20,"completion_tokens":11,"total_tokens":31}}


                  event: thread.run.completed

                  data:
                  {"id":"run_123","object":"thread.run","created_at":1710348075,"assistant_id":"asst_123","thread_id":"thread_123","status":"completed","started_at":1710348075,"expires_at":null,"cancelled_at":null,"failed_at":null,"completed_at":1710348077,"required_action":null,"last_error":null,"model":"gpt-4o","instructions":null,"tools":[],"metadata":{},"temperature":1.0,"top_p":1.0,"max_completion_tokens":null,"max_prompt_tokens":null,"truncation_strategy":{"type":"auto","last_messages":null},"incomplete_details":null,"usage":{"prompt_tokens":20,"completion_tokens":11,"total_tokens":31},"response_format":"auto","tool_choice":"auto","parallel_tool_calls":true}}


                  event: done

                  data: [DONE]

        """
        |> YamlElixir.read_all_from_string!()
        |> List.first()

      expected = %{
        name: "create_run",
        group: "foo",
        arguments: [
          %{
            in: "path",
            name: "thread_id",
            type: "string",
            required?: true,
            example: ""
          },
          %{
            in: "query",
            name: "include[]",
            type: "array",
            required?: false,
            example: ""
          }
        ],
        deprecated?: false,
        endpoint: "/foo/${engine_id}",
        method: :post,
        response_type: {:component, "RunObject"},
        summary: "Create a run.",
        request_body: %{
          required?: true,
          content_type: :"application/json",
          request_schema: nil
        }
      }

      actual = ExOpenAI.Codegen.parse_path("/foo/${engine_id}", handler_schema, %{})

      assert actual == expected
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
        group: "foo",
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
        group: "foo",
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
        group: "foo",
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
