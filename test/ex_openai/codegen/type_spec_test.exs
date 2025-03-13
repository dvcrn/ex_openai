defmodule ExOpenAI.Codegen.TypeSpecTest do
  use ExUnit.Case, async: true

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
end