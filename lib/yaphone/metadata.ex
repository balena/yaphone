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
    fixed_line: "fixedLine",
    mobile: "mobile",
    toll_free: "tollFree",
    premium_rate: "premiumRate",
    shared_cost: "sharedCost",
    personal_number: "personalNumber",
    voip: "voip",
    pager: "pager",
    uan: "uan",
    emergency: "emergency",
    voicemail: "voicemail",
    short_code: "shortCode",
    standard_rate: "standardRate",
    carrier_specific: "carrierSpecific",
    sms_services: "smsServices",
    no_international_dialing: "noInternationalDialing"
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

  def parse!(body, opts \\ []) do
    for territory <- xpath(body, ~x"//territories/territory"l) do
      metadata =
        territory
        |> parse_territory_tag_metadata()
        |> parse_available_formats(territory)

      # The alternate formats metadata does not need most of the patterns
      # to be set.
      case Keyword.get(opts, :alternate_formats, false) do
        false -> set_relevant_desc_patterns(metadata, territory, opts)
        true -> metadata
      end
    end
  end

  def set_relevant_desc_patterns(metadata, territory, opts) do
    general_desc =
      parse_phone_number_description(nil, territory, "generalDesc", opts)
      |> set_possible_lengths_general_desc(metadata.id, territory)

    metadata =
      for {key, tag} <- @phone_number_descriptions, reduce: metadata do
        acc ->
          desc = parse_phone_number_description(general_desc, territory, tag, opts)
          %{acc | key => desc}
      end

    %{
      metadata
      | general_desc: general_desc,
        same_mobile_and_fixed_line_pattern:
          metadata.fixed_line.national_number_pattern ==
            metadata.mobile.national_number_pattern
    }
  end

  def parse_territory_tag_metadata(territory) do
    fields =
      xpath(territory, ~x".",
        id: ~x"@id"s |> transform_by(&String.to_atom/1),
        country_code: ~x"@countryCode"i,
        international_prefix: ~x"@internationalPrefix"s |> transform_by(&parse_regex(&1)),
        preferred_international_prefix:
          ~x"@preferredInternationalPrefix"o |> transform_by(&(&1 && to_string(&1))),
        national_prefix: ~x"@nationalPrefix"s,
        preferred_extn_prefix: ~x"@preferredExtnPrefix"o |> transform_by(&(&1 && to_string(&1))),
        national_prefix_for_parsing:
          ~x"@nationalPrefixForParsing"o
          |> transform_by(&(&1 && parse_regex(&1, true))),
        national_prefix_transform_rule:
          ~x"@nationalPrefixTransformRule"o |> transform_by(&(&1 && parse_regex(&1))),
        same_mobile_and_fixed_line_pattern:
          ~x"@nationalPrefixTransformRule"s |> transform_by(&(&1 == "true")),
        main_country_for_code: ~x"@mainCountryForCode"s |> transform_by(&(&1 == "true")),
        leading_digits: ~x"@leadingDigits"o |> transform_by(&(&1 && parse_regex(&1))),
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
          &(&1 &&
              parse_formatting_rule_with_placeholders(&1, metadata.national_prefix)
              |> parse_regex())
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
                &(&1 &&
                    parse_formatting_rule_with_placeholders(&1, metadata.national_prefix)
                    |> parse_regex())
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
          pattern: xpath(number_format, ~x"@pattern"s |> transform_by(&parse_regex(&1))),
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
      parse_regex(leading_digit, true)
    end
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

  @doc """
  Processes a phone number description element from the XML file and returns it
  as a `Yaphone.Metadata.PhoneNumberDescription`.

  If the description element is a fixed line or mobile number, the parent
  description will be used to fill in the whole element if necessary, or any
  components that are missing. For all other types, the parent description will
  only be used to fill in missing components if the type has a partial
  definition. For example, if no "tollFree" element exists, we assume there are
  no toll free numbers for that locale, and return a phone number description
  with no national number data and [-1] for the possible lengths.  Note that
  the parent description must therefore already be processed before this method
  is called on any child elements.
  """
  def parse_phone_number_description(parent_desc, territory, number_type, opts \\ []) do
    case xpath(territory, ~x"./#{number_type}"l) do
      [] ->
        # -1 will never match a possible phone number length, so is safe to use
        # to ensure this never matches. We don't leave it empty, since for
        # compression reasons, we use the empty list to mean that the
        # generalDesc possible lengths apply.
        %Yaphone.Metadata.PhoneNumberDescription{possible_length: [-1]}

      [desc] ->
        fields_opts =
          [
            national_number_pattern:
              ~x"./nationalNumberPattern/text()"o |> transform_by(&(&1 && parse_regex(&1, true)))
          ] ++
            if Keyword.get(opts, :lite_build, false) or
                 (Keyword.get(opts, :special_build, false) and number_type != "mobile") do
              []
            else
              [
                example_number:
                  ~x"./exampleNumber/text()"o |> transform_by(&(&1 && to_string(&1)))
              ]
            end

        number_desc =
          struct(Yaphone.Metadata.PhoneNumberDescription, xpath(desc, ~x"."k, fields_opts))

        if parent_desc != nil do
          {lengths, local_only_lengths} = parse_possible_lengths(desc)

          number_desc
          |> set_possible_lengths(lengths, local_only_lengths, parent_desc)
        else
          number_desc
        end

      _ ->
        raise ArgumentError, message: "Multiple elements with type #{number_type} found."
    end
  end

  def parse_possible_lengths(desc) do
    {lengths, local_only_lengths} =
      for element <- xpath(desc, ~x"possibleLengths"l), reduce: {[], []} do
        {result_lengths, result_local_only_lengths} ->
          # We don't add to the phone metadata yet, since we want to sort length
          # elements found under different nodes first, make sure there are no
          # duplicates between them and that the localOnly lengths don't overlap
          # with the others.
          lengths =
            xpath(element, ~x"@national"s)
            |> parse_possible_lengths_string()

          case xpath(element, ~x"@localOnly"o) do
            nil ->
              {result_lengths ++ lengths, result_local_only_lengths}

            local_only_lengths_string ->
              local_only_lengths = parse_possible_lengths_string(local_only_lengths_string)

              intersection =
                MapSet.intersection(MapSet.new(local_only_lengths), MapSet.new(lengths))

              unless Enum.empty?(intersection) do
                raise ArgumentError,
                  message:
                    "Possible length(s) found specified as a normal and local-only " <>
                      "length: #{inspect(MapSet.to_list(intersection))}"
              end

              {result_lengths ++ lengths, result_local_only_lengths ++ local_only_lengths}
          end
      end

    {Enum.uniq(lengths), Enum.uniq(local_only_lengths)}
  end

  defp parse_possible_lengths_string(charlist) when is_list(charlist),
    do: parse_possible_lengths_string(to_string(charlist))

  defp parse_possible_lengths_string(string) when is_binary(string) do
    lengths =
      for part <- String.split(string, ","), part != "", reduce: [] do
        acc -> acc ++ parse_length_part(part)
      end

    unless Enum.empty?(lengths -- Enum.uniq(lengths)) do
      raise ArgumentError,
        message:
          "Duplicate length element found " <>
            "in possibleLength string #{string}"
    end

    lengths
  end

  defp parse_length_part("[" <> string) do
    [from, to] =
      string
      |> String.trim_trailing("]")
      |> String.split("-")

    for i <- String.to_integer(from)..String.to_integer(to), do: i
  end

  defp parse_length_part(length), do: [String.to_integer(length)]

  def set_possible_lengths_general_desc(general_desc, metadata_id, territory, opts \\ []) do
    # The general description node should *always* be present if metadata for
    # other types is present, aside from in some unit tests.  (However, for
    # e.g. formatting metadata in PhoneNumberAlternateFormats, no
    # PhoneNumberDesc elements are present).
    if (general_desc.possible_length != [-1] and not Enum.empty?(general_desc.possible_length)) or
         not Enum.empty?(general_desc.possible_length_local_only) do
      # We shouldn't have anything specified at the "general desc" level: we
      # are going to calculate this ourselves from child elements.
      raise ArgumentError,
        message:
          "Found possible lengths specified at general " <>
            "desc: this should be derived from child elements. Affected country: #{inspect(metadata_id)}"
    end

    {lengths, local_only_lengths} =
      if Keyword.get(opts, :short_number, false) do
        # For short number metadata, we want to copy the lengths from the
        # "short code" section only.  This is because it's the more detailed
        # validation pattern, it's not a sub-type of short codes. The other
        # lengths will be checked later to see that they are a sub-set of these
        # possible lengths.
        {lengths, local_only_lengths} =
          case xpath(territory, ~x"shortCode"o) do
            nil -> {[], []}
            element -> parse_possible_lengths(element)
          end

        unless Enum.empty?(local_only_lengths) do
          raise ArgumentError, "Found local-only lengths in short-number metadata"
        end

        {lengths, []}
      else
        for {_key, tag} <- @phone_number_descriptions,
            tag not in [:no_international_dialing],
            reduce: {[], []} do
          {returned_lengths, returned_local_only_lengths} ->
            {lengths, local_only_lengths} =
              case xpath(territory, ~x"#{tag}"o) do
                nil -> {[], []}
                element -> parse_possible_lengths(element)
              end

            {returned_lengths ++ lengths, returned_local_only_lengths ++ local_only_lengths}
        end
      end

    possible_length = Enum.uniq(lengths)

    possible_length_local_only =
      local_only_lengths
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(possible_length))
      |> MapSet.to_list()

    %{
      general_desc
      | possible_length: possible_length,
        possible_length_local_only: possible_length_local_only
    }
  end

  @doc """
  Sets the possible length fields in the metadata from the sets of data passed
  in. Checks that the length is covered by the "parent" phone number
  description element if one is present, and if the lengths are exactly the
  same as this, they are not filled in for efficiency reasons.
  """
  def set_possible_lengths(desc, lengths, local_only_lengths, nil) do
    local_only_lengths =
      MapSet.new(local_only_lengths)
      |> MapSet.difference(MapSet.new(lengths))
      |> MapSet.to_list()

    %{desc | possible_length: lengths, possible_length_local_only: local_only_lengths}
  end

  def set_possible_lengths(desc, lengths, local_only_lengths, parent_desc) do
    unless MapSet.new(lengths)
           |> MapSet.difference(MapSet.new(parent_desc.possible_length))
           |> Enum.empty?() do
      # We shouldn't have possible lengths defined in a child element that are not covered by
      # the general description. We check this here even though the general description is
      # derived from child elements because it is only derived from a subset, and we need to
      # ensure *all* child elements have a valid possible length.
      raise ArgumentError,
        message:
          "Out-of-range possible length found: " <>
            "#{inspect(lengths, charlists: :as_lists)} != " <>
            "#{inspect(parent_desc.possible_length, charlists: :as_lists)}."
    end

    # Only add the lengths to this sub-type if they aren't exactly the same as
    # the possible lengths in the general desc (for metadata size reasons).
    desc =
      case MapSet.new(lengths) == MapSet.new(parent_desc.possible_length) do
        true ->
          desc

        false ->
          intersection =
            MapSet.new(lengths)
            |> MapSet.intersection(MapSet.new(parent_desc.possible_length))
            |> MapSet.to_list()

          %{desc | possible_length: intersection}
      end

    # We check that the local-only length isn't also a normal possible length
    # (only relevant for the general-desc, since within elements such as
    # fixed-line we would throw an exception if we saw this) before adding it
    # to the collection of possible local-only lengths.
    local_only_lengths =
      MapSet.new(local_only_lengths)
      |> MapSet.difference(MapSet.new(lengths))
      |> MapSet.to_list()

    unless MapSet.new(local_only_lengths)
           |> MapSet.difference(
             MapSet.union(
               MapSet.new(parent_desc.possible_length),
               MapSet.new(parent_desc.possible_length_local_only)
             )
           )
           |> Enum.empty?() do
      # We check it is covered by either of the possible length sets of
      # the parent PhoneNumberDesc, because for example 7 might be a
      # valid localOnly length for mobile, but a valid national length
      # for fixedLine, so the generalDesc would have the 7 removed from
      # localOnly.
      raise ArgumentError,
        message:
          "Out-of-range local-only possible length found: " <>
            "#{inspect(local_only_lengths, charlists: :as_lists)} != " <>
            "#{inspect(parent_desc.possible_length_local_only, charlists: :as_lists)}."
    end

    %{desc | possible_length_local_only: local_only_lengths}
  end

  def parse_regex(regex, remove_whitespace \\ false)

  def parse_regex(regex, remove_whitespace) when is_list(regex),
    do: parse_regex(to_string(regex), remove_whitespace)

  def parse_regex(regex, remove_whitespace) when is_binary(regex) do
    # Removes all the whitespace and newline from the regexp. Not using pattern
    # compile options to make it work across programming languages.
    compressed_regex =
      case remove_whitespace do
        true -> Regex.replace(~r/[[:space:]]+/, regex, "")
        false -> regex
      end

    Regex.compile!(compressed_regex)

    # We don't ever expect to see | followed by a ) in our metadata - this
    # would be an indication of a bug. If one wants to make something optional,
    # we prefer ? to using an empty group.
    unless not String.contains?(compressed_regex, "|)") do
      raise ArgumentError, "| followed by )"
    end

    # return the regex if it is of correct syntax, i.e. compile did not fail with a
    # PatternSyntaxException.
    compressed_regex
  end
end
