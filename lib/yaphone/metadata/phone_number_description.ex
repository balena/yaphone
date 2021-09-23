defmodule Yaphone.Metadata.PhoneNumberDescription do
  @type t :: %__MODULE__{
          national_number_pattern: Regex.t() | nil,
          possible_length: [integer],
          possible_length_local_only: [integer],
          example_number: String.t() | nil
        }

  defstruct national_number_pattern: nil,
            possible_length: [],
            possible_length_local_only: [],
            example_number: nil
end
