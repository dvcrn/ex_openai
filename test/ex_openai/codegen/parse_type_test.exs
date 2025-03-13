defmodule ExOpenAI.Codegen.ParseTypeTest do
  use ExUnit.Case, async: true

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
end
