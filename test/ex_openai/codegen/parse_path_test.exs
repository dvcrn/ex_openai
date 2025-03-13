defmodule ExOpenAI.Codegen.ParsePathTest do
  use ExUnit.Case, async: true

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
