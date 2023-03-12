defmodule ExOpenAI.Jason do
  @moduledoc false

  # Module to package all the protocol stuff for Jason away

  defmacro __using__(_opts) do
    quote do
      defimpl Jason.Encoder, for: [__MODULE__] do
        # remove nil fields
        def encode(struct, opts) when is_struct(struct) do
          to_encode =
            for {key, value} <- Map.to_list(struct),
                value != nil,
                key != :__struct__,
                do: {key, value}

          Jason.Encode.keyword(to_encode, opts)
        end

        # fallback
        def encode(atom, opts) do
          Jason.Encode.encode(atom, opts)
        end
      end
    end
  end
end
