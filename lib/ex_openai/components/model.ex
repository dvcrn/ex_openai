defmodule ExOpenAI.Components.Model do
  @moduledoc """
  Replacement Component for Model API responses
  This module was not part of the api documentation and got probably forgotten, so it has been manually provided by this package
  Rpresents API responses such as:
  ```
  created: 1649880484,
  id: "text-davinci-insert-002",
  object: "model",
  owned_by: "openai",
  parent: nil,
  permission: [
    %{
      allow_create_engine: false,
      allow_fine_tuning: false,
      allow_logprobs: true,
      allow_sampling: true,
      allow_search_indices: false,
      allow_view: true,
      created: 1669066354,
      group: nil,
      id: "modelperm-V5YQoSyiapAf4km5wisXkNXh",
      is_blocking: false,
      object: "model_permission",
      organization: "*"
    }
  ],
  root: "text-davinci-insert-002"
  ```
  """

  use ExOpenAI.Jason
  defstruct [:created, :id, :object, :owned_by, :parent, :permission, :root]

  @typespec quote(
              do: %{
                created: integer,
                id: String.t(),
                object: String.t(),
                owned_by: String.t(),
                parent: String.t(),
                root: String.t(),
                permission: [
                  %{
                    allow_create_engine: boolean(),
                    allow_fine_tuning: boolean(),
                    allow_logprobs: boolean(),
                    allow_sampling: boolean(),
                    allow_search_indices: boolean(),
                    allow_view: boolean(),
                    created: integer,
                    group: String.t(),
                    id: String.t(),
                    is_blocking: boolean(),
                    object: String.t(),
                    organization: String.t()
                  }
                ]
              }
            )

  def unpack_ast(partial_tree \\ %{}) do
    Map.put(partial_tree, __MODULE__, @typespec)
  end

  @type t :: %{
          created: integer,
          id: String.t(),
          object: String.t(),
          owned_by: String.t(),
          parent: String.t(),
          root: String.t(),
          permission: [
            %{
              allow_create_engine: boolean(),
              allow_fine_tuning: boolean(),
              allow_logprobs: boolean(),
              allow_sampling: boolean(),
              allow_search_indices: boolean(),
              allow_view: boolean(),
              created: integer,
              group: String.t(),
              id: String.t(),
              is_blocking: boolean(),
              object: String.t(),
              organization: String.t()
            }
          ]
        }
end
