defmodule Yaphone.Metadata do
  @moduledoc false

  import SweetXml

  @type t :: %__MODULE__{
          general_desc: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          fixed_line: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          mobile: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          toll_free: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          premium_rate: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          shared_cost: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          personal_number: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          voip: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          pager: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          uan: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          emergency: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          voicemail: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          short_code: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          standard_rate: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          carrier_specific: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          sms_services: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          no_international_dialing: Yaphone.Metadata.PhoneNumberDescription.t() | nil,
          id: atom,
          country_code: integer,
          international_prefix: String.t() | nil,
          preferred_international_prefix: String.t() | nil,
          national_prefix: String.t() | nil,
          preferred_extn_prefix: String.t() | nil,
          national_prefix_for_parsing: Regex.t() | nil,
          national_prefix_transform_rule: String.t() | nil,
          same_mobile_and_fixed_line_pattern: boolean,
          number_format: [Yaphone.Metadata.NumberFormat.t()],
          intl_number_format: [Yaphone.Metadata.NumberFormat.t()],
          main_country_for_code: boolean,
          leading_digits: String.t() | nil,
          leading_zero_possible: boolean,
          mobile_number_portable_region: boolean
        }

  @type xml_input :: SweetXml.doc() | SweetXml.xmlElement()
  @type number_format :: %Yaphone.Metadata.NumberFormat{}

  @phone_number_descriptions [
    general_desc: ~x"./generalDesc"o,
    fixed_line: ~x"./fixedLine"o,
    mobile: ~x"./mobile"o,
    toll_free: ~x"./tollFree"o,
    premium_rate: ~x"./premiumRate"o,
    shared_cost: ~x"./sharedCost"o,
    personal_number: ~x"./personalNumber"o,
    voip: ~x"./voip"o,
    pager: ~x"./pager"o,
    uan: ~x"./uan"o,
    emergency: ~x"./emergency"o,
    voicemail: ~x"./voicemail"o,
    short_code: ~x"./shortCode"o,
    standard_rate: ~x"./standardRate"o,
    carrier_specific: ~x"./carrierSpecific"o,
    sms_services: ~x"./smsServices"o,
    no_international_dialing: ~x"./noInternationalDialing"o
  ]

  defstruct general_desc: nil,
            fixed_line: nil,
            mobile: nil,
            toll_free: nil,
            premium_rate: nil,
            shared_cost: nil,
            personal_number: nil,
            voip: nil,
            pager: nil,
            uan: nil,
            emergency: nil,
            voicemail: nil,
            short_code: nil,
            standard_rate: nil,
            carrier_specific: nil,
            sms_services: nil,
            no_international_dialing: nil,
            id: :ZZ,
            country_code: 0,
            international_prefix: nil,
            preferred_international_prefix: nil,
            national_prefix: nil,
            preferred_extn_prefix: nil,
            national_prefix_for_parsing: nil,
            national_prefix_transform_rule: nil,
            same_mobile_and_fixed_line_pattern: false,
            number_format: [],
            intl_number_format: [],
            main_country_for_code: nil,
            leading_digits: nil,
            leading_zero_possible: false,
            mobile_number_portable_region: false

  def parse!(body) do
    for territory <- xpath(body, ~x"//territories/territory"l) do
      metadata =
        territory
        |> parse_territory_tag_metadata()
        |> parse_available_formats(territory)

      metadata =
        for {key, path} <- @phone_number_descriptions, reduce: metadata do
          acc -> %{acc | key => parse_phone_number_description(xpath(territory, path))}
        end

      %{
        metadata
        | same_mobile_and_fixed_line_pattern:
            metadata.fixed_line.national_number_pattern == metadata.mobile.national_number_pattern
      }
    end
  end

  def parse_territory_tag_metadata(territory) do
    fields =
      xpath(territory, ~x".",
        id: ~x"@id"s |> transform_by(&String.to_atom/1),
        country_code: ~x"@countryCode"i,
        international_prefix: ~x"@internationalPrefix"s,
        preferred_international_prefix:
          ~x"@preferredInternationalPrefix"o |> transform_by(&(&1 && to_string(&1))),
        national_prefix: ~x"@nationalPrefix"s,
        preferred_extn_prefix: ~x"@preferredExtnPrefix"o |> transform_by(&(&1 && to_string(&1))),
        national_prefix_for_parsing:
          ~x"@nationalPrefixForParsing"o
          |> transform_by(&(&1 && to_string(&1))),
        national_prefix_transform_rule:
          ~x"@nationalPrefixTransformRule"o |> transform_by(&(&1 && to_string(&1))),
        same_mobile_and_fixed_line_pattern:
          ~x"@nationalPrefixTransformRule"s |> transform_by(&(&1 == "true")),
        main_country_for_code: ~x"@mainCountryForCode"s |> transform_by(&(&1 == "true")),
        leading_digits: ~x"@leadingDigits"o |> transform_by(&(&1 && to_string(&1))),
        leading_zero_possible: ~x"@leadingZeroPossible"s |> transform_by(&(&1 == "true")),
        mobile_number_portable_region:
          ~x"@mobileNumberPortableRegion"s |> transform_by(&(&1 == "true"))
      )

    fields = %{
      fields
      | national_prefix_for_parsing: fields.national_prefix_for_parsing || fields.national_prefix
    }

    struct(__MODULE__, fields)
  end

  def parse_available_formats(metadata, territory) do
    default_national_prefix_formatting_rule =
      xpath(
        territory,
        ~x"@nationalPrefixFormattingRule"o
        |> transform_by(
          &(&1 && parse_formatting_rule_with_placeholders(&1, metadata.national_prefix))
        )
      )

    default_national_prefix_optional_when_formatting =
      xpath(
        territory,
        ~x"@nationalPrefixOptionalWhenFormatting"s |> transform_by(&(&1 == "true"))
      )

    default_carrier_code_formatting_rule =
      xpath(
        territory,
        ~x"@carrierCodeFormattingRule"o
        |> transform_by(
          &(&1 && parse_formatting_rule_with_placeholders(&1, metadata.national_prefix))
        )
      )

    {number_formats, intl_formats, explicit_intl_defined} =
      for number_format <- xpath(territory, ~x"./availableFormats/numberFormat"l),
          reduce: {[], [], false} do
        {national_formats, intl_formats, previous_explicit_intl_defined} ->
          national_prefix_formatting_rule =
            xpath(
              number_format,
              ~x"@nationalPrefixFormattingRule"o
              |> transform_by(
                &(&1 && parse_formatting_rule_with_placeholders(&1, metadata.national_prefix))
              )
            )

          national_prefix_optional_when_formatting =
            xpath(
              number_format,
              ~x"@nationalPrefixOptionalWhenFormatting"s
              |> transform_by(&(&1 && &1 == "true"))
            )

          carrier_code_formatting_rule =
            xpath(
              number_format,
              ~x"@carrierCodeFormattingRule"o
              |> transform_by(
                &(&1 && parse_formatting_rule_with_placeholders(&1, metadata.national_prefix))
              )
            )

          national_format = parse_national_format(metadata, number_format)

          national_format = %{
            national_format
            | national_prefix_formatting_rule:
                national_prefix_formatting_rule || default_national_prefix_formatting_rule,
              national_prefix_optional_when_formatting:
                national_prefix_optional_when_formatting ||
                  default_national_prefix_optional_when_formatting,
              domestic_carrier_code_formatting_rule:
                carrier_code_formatting_rule || default_carrier_code_formatting_rule
          }

          {intl_format, explicit_intl_defined} =
            parse_international_format(metadata, number_format, national_format)

          {national_formats ++ [national_format],
           if(intl_format == nil, do: intl_formats, else: intl_formats ++ [intl_format]),
           previous_explicit_intl_defined || explicit_intl_defined}
      end

    %{
      metadata
      | number_format: number_formats,
        intl_number_format: if(explicit_intl_defined, do: intl_formats, else: [])
    }
  end

  @doc """
  Parses the pattern for the national format.

  Raises if multiple or no formats have been encountered.
  """
  @spec parse_national_format(t, xml_input) :: number_format
  def parse_national_format(metadata, number_format) do
    case xpath(number_format, ~x"./format"l) do
      [format] ->
        %Yaphone.Metadata.NumberFormat{
          pattern: xpath(number_format, ~x"@pattern"s),
          format: xpath(format, ~x"./text()"s),
          leading_digits_pattern: parse_leading_digits_patterns(number_format)
        }

      other ->
        raise ArgumentError,
          message:
            "Invalid number of format patterns (#{length(other)}) for country: #{inspect(metadata.id)}"
    end
  end

  @doc """
  Extracts the pattern for international format.

  Return value is a tuple consisting of a `Yaphone.Metadata.NumberFormat.t`
  representing the intlFormat, and a boolean flag whether an international
  number format is defined.

  If there is no intlFormat, default to using the national format. If the
  intlFormat is set to "NA" the intlFormat is `nil`.

  It will raise an exception if multiple intlFormats have been encountered.
  """
  @spec parse_international_format(t, xml_input, number_format) :: {number_format | nil, boolean}
  def parse_international_format(metadata, number_format, national_format) do
    case xpath(number_format, ~x"./intlFormat"l) do
      [] ->
        # Default to use the same as the national pattern if none is defined.
        {national_format, false}

      [intl_format] ->
        intl_format_pattern_value = xpath(intl_format, ~x"./text()"s)

        intl_format =
          case intl_format_pattern_value do
            "NA" ->
              nil

            _ ->
              %Yaphone.Metadata.NumberFormat{
                pattern: xpath(number_format, ~x"@pattern"s),
                format: intl_format_pattern_value,
                leading_digits_pattern: parse_leading_digits_patterns(number_format)
              }
          end

        {intl_format, true}

      _ ->
        raise ArgumentError,
          message: "Invalid number of intlFormat patterns for country: #{inspect(metadata.id)}"
    end
  end

  @doc """
  Parses leadingDigits from a numberFormat element and validates each regular expression.
  """
  def parse_leading_digits_patterns(number_format) do
    for leading_digit <- xpath(number_format, ~x"./leadingDigits/text()"sl) do
      validate_regex(leading_digit)
    end
  end

  def validate_regex(string) do
    string
  end

  @doc """
  Replace $NP with national prefix and $FG with the first group ($1).
  """
  def parse_formatting_rule_with_placeholders(string, national_prefix) when is_list(string) do
    string
    |> to_string()
    |> parse_formatting_rule_with_placeholders(national_prefix)
  end
  
  def parse_formatting_rule_with_placeholders(string, national_prefix) when is_binary(string) do
    string
    |> String.replace("$NP", national_prefix)
    |> String.replace("$FG", "$1")
  end

  defp parse_phone_number_description(nil),
    do: %Yaphone.Metadata.PhoneNumberDescription{possible_length: [-1]}

  defp parse_phone_number_description(elem) do
    fields =
      xpath(elem, ~x".",
        national_number_pattern:
          ~x"./nationalNumberPattern/text()"s |> transform_by(&Regex.compile!(&1, "x")),
        possible_length: ~x"./possibleLengths/@national"s |> transform_by(&parse_length/1),
        possible_length_local_only:
          ~x"./possibleLengths/@localOnly"s |> transform_by(&parse_length/1),
        example_number: ~x"./exampleNumber/text()"s
      )

    struct(Yaphone.Metadata.PhoneNumberDescription, fields)
  end

  defp parse_length(string) do
    for part <- String.split(string, ","), part != "", reduce: [] do
      acc -> acc ++ parse_length_part(part)
    end
  end

  defp parse_length_part("[" <> string) do
    [from, to] =
      string
      |> String.trim_trailing("]")
      |> String.split("-")

    for i <- String.to_integer(from)..String.to_integer(to), do: i
  end

  defp parse_length_part(length), do: [String.to_integer(length)]
end
