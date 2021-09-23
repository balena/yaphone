defmodule Yaphone.Metadata.NumberFormat do
  @type t :: %__MODULE__{
          pattern: Regex.t(),
          format: String.t(),
          leading_digits_pattern: [Regex.t()],
          national_prefix_formatting_rule: String.t() | nil,
          national_prefix_optional_when_formatting: boolean,
          domestic_carrier_code_formatting_rule: String.t() | nil
        }

  defstruct pattern: ~r/^$/,
            format: "",
            leading_digits_pattern: [],
            national_prefix_formatting_rule: nil,
            national_prefix_optional_when_formatting: false,
            domestic_carrier_code_formatting_rule: nil
end
