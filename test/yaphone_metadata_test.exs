defmodule YaphoneMetadataTest do
  use ExUnit.Case

  test "parse_regex removes whitespace" do
    input = " hello world "

    # Should remove all the white spaces contained in the provided string.
    assert "helloworld" == Yaphone.Metadata.parse_regex(input, true)

    # Make sure it only happens when the last parameter is set to true.
    assert " hello world " == Yaphone.Metadata.parse_regex(input, false)
  end

  test "parse_regex raises when regex is invalid" do
    invalid_pattern = "["

    # Should throw an exception when an invalid pattern is provided
    # independently of the last parameter (remove white spaces).
    assert_raise Regex.CompileError, fn ->
      Yaphone.Metadata.parse_regex(invalid_pattern, false)
    end

    assert_raise Regex.CompileError, fn ->
      Yaphone.Metadata.parse_regex(invalid_pattern, true)
    end

    # We don't allow | to be followed by ) because it introduces bugs, since we
    # typically use it at the end of each line and when a line is deleted, if
    # the pipe from the previous line is not removed, we end up erroneously
    # accepting an empty group as well.
    assert_raise ArgumentError, fn ->
      Yaphone.Metadata.parse_regex("(a|)", true)
    end

    assert_raise ArgumentError, fn ->
      Yaphone.Metadata.parse_regex("(a|\n)", true)
    end
  end

  test "parse_regex" do
    valid_pattern = "[a-zA-Z]d{1,9}"

    # The provided pattern should be left unchanged.
    assert valid_pattern == Yaphone.Metadata.parse_regex(valid_pattern, false)
  end

  test "national_prefix" do
    xml_input = """
    <territory id='AC' countryCode='247' nationalPrefix='00'/>
    """

    meta = Yaphone.Metadata.parse_territory_tag_metadata(xml_input)

    assert meta.national_prefix == "00"
  end

  test "parse_territory_tag_metadata" do
    xml_input = """
    <territory
      countryCode='33' leadingDigits='2' internationalPrefix='00'
      preferredInternationalPrefix='00~11' nationalPrefixForParsing='0'
      nationalPrefixTransformRule='9$1' nationalPrefix='0'
      preferredExtnPrefix=' x' mainCountryForCode='true'
      leadingZeroPossible='true' mobileNumberPortableRegion='true'>
    </territory>
    """

    meta = Yaphone.Metadata.parse_territory_tag_metadata(xml_input)

    assert 33 == meta.country_code
    assert "2" == meta.leading_digits
    assert "00" == meta.international_prefix
    assert "00~11" == meta.preferred_international_prefix
    assert "0" == meta.national_prefix_for_parsing
    assert "9$1" == meta.national_prefix_transform_rule
    assert "0" == meta.national_prefix
    assert " x" == meta.preferred_extn_prefix
    assert true == meta.main_country_for_code
    assert true == meta.mobile_number_portable_region
  end

  test "parse_territory_tag_metadata sets boolean fields to false by default" do
    xml_input = """
    <territory id='ZZ' countryCode='33'/>
    """

    meta = Yaphone.Metadata.parse_territory_tag_metadata(xml_input)

    assert false == meta.main_country_for_code
    assert false == meta.mobile_number_portable_region
  end

  test "parse_international_format uses national format by default" do
    national_pattern = "$1 $2 $3"

    xml_input = """
    <numberFormat>
      <format>#{national_pattern}</format>
    </numberFormat>
    """

    metadata = %Yaphone.Metadata{}
    national_format = Yaphone.Metadata.parse_national_format(metadata, xml_input)

    {intl_format, explicit_intl_defined} =
      Yaphone.Metadata.parse_international_format(metadata, xml_input, national_format)

    assert explicit_intl_defined == false
    assert national_format.format == national_pattern
    assert national_format.format == intl_format.format
  end

  test "parse_international_format copies national format data" do
    national_pattern = "$1-$2"

    xml_input = """
    <numberFormat>
      <format>#{national_pattern}</format>
    </numberFormat>
    """

    metadata = %Yaphone.Metadata{}
    national_format = Yaphone.Metadata.parse_national_format(metadata, xml_input)
    national_format = %{national_format | national_prefix_optional_when_formatting: true}

    {intl_format, explicit_intl_defined} =
      Yaphone.Metadata.parse_international_format(metadata, xml_input, national_format)

    assert explicit_intl_defined == false
    assert intl_format.national_prefix_optional_when_formatting == true
  end

  test "parse_national_format" do
    national_pattern = "$1 $2"

    xml_input = """
    <numberFormat>
      <format>#{national_pattern}</format>
    </numberFormat>
    """

    metadata = %Yaphone.Metadata{}
    national_format = Yaphone.Metadata.parse_national_format(metadata, xml_input)

    assert national_format.format == national_pattern
  end

  test "parse_national_format requires format" do
    xml_input = """
    <numberFormat></numberFormat>
    """

    metadata = %Yaphone.Metadata{}

    assert_raise ArgumentError, ~r/^Invalid number of format patterns/, fn ->
      Yaphone.Metadata.parse_national_format(metadata, xml_input)
    end
  end

  test "parse_national_format expects exactly one format" do
    xml_input = """
    <numberFormat><format/><format/></numberFormat>
    """

    metadata = %Yaphone.Metadata{}

    assert_raise ArgumentError, ~r/^Invalid number of format patterns/, fn ->
      Yaphone.Metadata.parse_national_format(metadata, xml_input)
    end
  end

  test "parse_available_formats" do
    xml_input = """
    <territory>
      <availableFormats>
        <numberFormat nationalPrefixFormattingRule='($FG)'
                      carrierCodeFormattingRule='$NP $CC ($FG)'>
          <format>$1 $2 $3</format>
        </numberFormat>
      </availableFormats>
    </territory>
    """

    %{number_format: [national_format]} =
      %Yaphone.Metadata{national_prefix: "0"}
      |> Yaphone.Metadata.parse_available_formats(xml_input)

    assert national_format.national_prefix_formatting_rule == "($1)"
    assert national_format.domestic_carrier_code_formatting_rule == "0 $CC ($1)"
    assert national_format.format == "$1 $2 $3"
  end

  test "parse_available_formats propagates carrier_code_formalling_rule" do
    xml_input = """
    <territory carrierCodeFormattingRule='$NP $CC ($FG)'>
      <availableFormats>
        <numberFormat nationalPrefixFormattingRule='($FG)'>
          <format>$1 $2 $3</format>
        </numberFormat>
      </availableFormats>
    </territory>
    """

    %{number_format: [national_format]} =
      %Yaphone.Metadata{national_prefix: "0"}
      |> Yaphone.Metadata.parse_available_formats(xml_input)

    assert national_format.national_prefix_formatting_rule == "($1)"
    assert national_format.domestic_carrier_code_formatting_rule == "0 $CC ($1)"
    assert national_format.format == "$1 $2 $3"
  end

  test "parse_available_formats sets provided national_prefix_formatting_rule" do
    xml_input = """
    <territory nationalPrefixFormattingRule='($FG)'>
      <availableFormats>
        <numberFormat>
          <format>$1 $2 $3</format>
        </numberFormat>
      </availableFormats>
    </territory>
    """

    %{number_format: [national_format]} =
      %Yaphone.Metadata{national_prefix: "0"}
      |> Yaphone.Metadata.parse_available_formats(xml_input)

    assert national_format.national_prefix_formatting_rule == "($1)"
  end

  test "parse_available_formats clears intl_number_format" do
    xml_input = """
    <territory>
      <availableFormats>
        <numberFormat>
          <format>$1 $2 $3</format>
        </numberFormat>
      </availableFormats>
    </territory>
    """

    metadata =
      %Yaphone.Metadata{national_prefix: "0"}
      |> Yaphone.Metadata.parse_available_formats(xml_input)

    assert metadata.intl_number_format == []
  end

  test "parse_available_formats handles multiple number_formats" do
    xml_input = """
    <territory>
      <availableFormats>
        <numberFormat><format>$1 $2 $3</format></numberFormat>
        <numberFormat><format>$1-$2</format></numberFormat>
      </availableFormats>
    </territory>
    """

    %{number_format: [first_national_format, second_national_format]} =
      %Yaphone.Metadata{national_prefix: "0"}
      |> Yaphone.Metadata.parse_available_formats(xml_input)

    assert first_national_format.format == "$1 $2 $3"
    assert second_national_format.format == "$1-$2"
  end

  test "parse_international_format does not set intl_format when NA" do
    xml_input = """
    <numberFormat><intlFormat>NA</intlFormat></numberFormat>
    """

    national_format = %Yaphone.Metadata.NumberFormat{
      format: "$1 $2"
    }

    {intl_format, _explicit_intl_defined} =
      %Yaphone.Metadata{national_prefix: "0"}
      |> Yaphone.Metadata.parse_international_format(xml_input, national_format)

    assert intl_format == nil
  end

  test "parse_leading_digits_patterns" do
    xml_input = """
    <numberFormat>
      <leadingDigits>1</leadingDigits><leadingDigits>2</leadingDigits>
    </numberFormat>
    """

    assert ["1", "2"] = Yaphone.Metadata.parse_leading_digits_patterns(xml_input)
  end

  # Tests setLeadingDigitsPatterns() in the case of international and national
  # formatting rules being present but not both defined for this numberFormat -
  # we don't want to add them twice.
  test "parse_leading_digits_patterns not added twice when intlFormat present" do
    xml_input = """
    <territory>
      <availableFormats>
        <numberFormat pattern='(1)(\\d{3})'>
          <leadingDigits>1</leadingDigits>
          <format>$1</format>
        </numberFormat>
        <numberFormat pattern='(2)(\\d{3})'>
          <leadingDigits>2</leadingDigits>
          <format>$1</format>
          <intlFormat>9-$1</intlFormat>
        </numberFormat>
      </availableFormats>
    </territory>
    """

    metadata =
      %Yaphone.Metadata{national_prefix: "0"}
      |> Yaphone.Metadata.parse_available_formats(xml_input)

    assert [%{leading_digits_pattern: ["1"]}, %{leading_digits_pattern: ["2"]}] =
             metadata.number_format

    # This is less of a problem for the Elixir implementation, as data is
    # immutable. But just in case, we shouldn't add the leading digit patterns
    # multiple times.
    assert [%{leading_digits_pattern: ["1"]}, %{leading_digits_pattern: ["2"]}] =
             metadata.intl_number_format
  end

  test "parse_formatting_rule_with_placeholders" do
    assert "0$1" == Yaphone.Metadata.parse_formatting_rule_with_placeholders('$NP$FG', "0")
    assert "0$1" == Yaphone.Metadata.parse_formatting_rule_with_placeholders("$NP$FG", "0")

    assert "0$CC $1" ==
             Yaphone.Metadata.parse_formatting_rule_with_placeholders("$NP$CC $FG", "0")
  end

  test "parse_phone_number_description with nil input" do
    general_desc = %Yaphone.Metadata.PhoneNumberDescription{}

    xml_input = """
    <territory/>
    """

    desc = Yaphone.Metadata.parse_phone_number_description(general_desc, xml_input, "invalidType")

    assert desc.national_number_pattern == nil
  end

  test "parse_phone_number_description overrides general_desc" do
    general_desc = %Yaphone.Metadata.PhoneNumberDescription{
      national_number_pattern: "\\d{8}"
    }

    xml_input = """
    <territory>
      <fixedLine>
        <nationalNumberPattern>\\d{6}</nationalNumberPattern>
      </fixedLine>
    </territory>
    """

    desc = Yaphone.Metadata.parse_phone_number_description(general_desc, xml_input, "fixedLine")

    assert "\\d{6}" == desc.national_number_pattern
  end

  test "parse! using lite_build" do
    xml_input = """
    <phoneNumberMetadata>
      <territories>
        <territory id="AM" countryCode="374" internationalPrefix="00">
          <generalDesc>
            <nationalNumberPattern>[1-9]\\d{7}</nationalNumberPattern>
          </generalDesc>
          <fixedLine>
            <nationalNumberPattern>[1-9]\\d{7}</nationalNumberPattern>
            <possibleLengths national="8" localOnly="5,6"/>
            <exampleNumber>10123456</exampleNumber>
          </fixedLine>
          <mobile>
            <nationalNumberPattern>[1-9]\\d{7}</nationalNumberPattern>
            <possibleLengths national="8" localOnly="5,6"/>
            <exampleNumber>10123456</exampleNumber>
          </mobile>
        </territory>
      </territories>
    </phoneNumberMetadata>
    """

    assert [metadata] = Yaphone.Metadata.parse!(xml_input, lite_build: true)
    assert metadata.general_desc.example_number == nil
    assert metadata.fixed_line.example_number == nil
    assert metadata.mobile.example_number == nil
  end

  test "parse! using special_build" do
    xml_input = """
    <phoneNumberMetadata>
      <territories>
        <territory id="AM" countryCode="374" internationalPrefix="00">
          <generalDesc>
            <nationalNumberPattern>[1-9]\\d{7}</nationalNumberPattern>
          </generalDesc>
          <fixedLine>
            <nationalNumberPattern>[1-9]\\d{7}</nationalNumberPattern>
            <possibleLengths national="8" localOnly="5,6"/>
            <exampleNumber>10123456</exampleNumber>
          </fixedLine>
          <mobile>
            <nationalNumberPattern>[1-9]\\d{7}</nationalNumberPattern>
            <possibleLengths national="8" localOnly="5,6"/>
            <exampleNumber>10123456</exampleNumber>
          </mobile>
        </territory>
      </territories>
    </phoneNumberMetadata>
    """

    assert [metadata] = Yaphone.Metadata.parse!(xml_input, special_build: true)
    assert metadata.general_desc.example_number == nil
    assert metadata.fixed_line.example_number == nil
    assert metadata.mobile.example_number == "10123456"
  end

  test "parse! using full build" do
    xml_input = """
    <phoneNumberMetadata>
      <territories>
        <territory id="AM" countryCode="374" internationalPrefix="00">
          <generalDesc>
            <nationalNumberPattern>[1-9]\\d{7}</nationalNumberPattern>
          </generalDesc>
          <fixedLine>
            <nationalNumberPattern>[1-9]\\d{7}</nationalNumberPattern>
            <possibleLengths national="8" localOnly="5,6"/>
            <exampleNumber>10123456</exampleNumber>
          </fixedLine>
          <mobile>
            <nationalNumberPattern>[1-9]\\d{7}</nationalNumberPattern>
            <possibleLengths national="8" localOnly="5,6"/>
            <exampleNumber>10123456</exampleNumber>
          </mobile>
        </territory>
      </territories>
    </phoneNumberMetadata>
    """

    assert [metadata] = Yaphone.Metadata.parse!(xml_input)
    assert metadata.general_desc.example_number == nil
    assert metadata.fixed_line.example_number == "10123456"
    assert metadata.mobile.example_number == "10123456"
  end

  test "parse_phone_number_description outputs example_number by default" do
    general_desc = %Yaphone.Metadata.PhoneNumberDescription{}

    xml_input = """
    <territory><fixedLine>
      <exampleNumber>01 01 01 01</exampleNumber>
    </fixedLine></territory>
    """

    desc = Yaphone.Metadata.parse_phone_number_description(general_desc, xml_input, "fixedLine")
    assert "01 01 01 01" == desc.example_number
  end

  test "parse_phone_number_description removes whitespaces in patterns" do
    general_desc = %Yaphone.Metadata.PhoneNumberDescription{}

    xml_input = """
    <territory><fixedLine>
      <nationalNumberPattern>\t \\d { 6 } </nationalNumberPattern>
    </fixedLine></territory>
    """

    desc = Yaphone.Metadata.parse_phone_number_description(general_desc, xml_input, "fixedLine")
    assert "\\d{6}" == desc.national_number_pattern
  end

  test "parse! sets same_mobile_and_fixed_line_pattern" do
    xml_input = """
    <phoneNumberMetadata>
      <territories>
        <territory id="ZZ" countryCode="33">
          <fixedLine><nationalNumberPattern>\\d{6}</nationalNumberPattern></fixedLine>
          <mobile><nationalNumberPattern>\\d{6}</nationalNumberPattern></mobile>
        </territory>
      </territories>
    </phoneNumberMetadata>
    """

    [metadata] = Yaphone.Metadata.parse!(xml_input)

    # Should set same_mobile_and_fixed_line_pattern to true.
    assert metadata.same_mobile_and_fixed_line_pattern == true
  end

  test "parse! sets all descriptions for regular length numbers" do
    xml_input = """
    <phoneNumberMetadata>
      <territories>
        <territory countryCode="33">
          <fixedLine><nationalNumberPattern>\\d{1}</nationalNumberPattern></fixedLine>
          <mobile><nationalNumberPattern>\\d{2}</nationalNumberPattern></mobile>
          <pager><nationalNumberPattern>\\d{3}</nationalNumberPattern></pager>
          <tollFree><nationalNumberPattern>\\d{4}</nationalNumberPattern></tollFree>
          <premiumRate><nationalNumberPattern>\\d{5}</nationalNumberPattern></premiumRate>
          <sharedCost><nationalNumberPattern>\\d{6}</nationalNumberPattern></sharedCost>
          <personalNumber><nationalNumberPattern>\\d{7}</nationalNumberPattern></personalNumber>
          <voip><nationalNumberPattern>\\d{8}</nationalNumberPattern></voip>
          <uan><nationalNumberPattern>\\d{9}</nationalNumberPattern></uan>
        </territory>
      </territories>
    </phoneNumberMetadata>
    """

    [metadata] = Yaphone.Metadata.parse!(xml_input)

    assert "\\d{1}" == metadata.fixed_line.national_number_pattern
    assert "\\d{2}" == metadata.mobile.national_number_pattern
    assert "\\d{3}" == metadata.pager.national_number_pattern
    assert "\\d{4}" == metadata.toll_free.national_number_pattern
    assert "\\d{5}" == metadata.premium_rate.national_number_pattern
    assert "\\d{6}" == metadata.shared_cost.national_number_pattern
    assert "\\d{7}" == metadata.personal_number.national_number_pattern
    assert "\\d{8}" == metadata.voip.national_number_pattern
    assert "\\d{9}" == metadata.uan.national_number_pattern
  end

  test "parse! sets all descriptions for short numbers" do
    xml_input = """
    <phoneNumberMetadata>
      <territories>
        <territory ID="FR" countryCode="33">
          <tollFree><nationalNumberPattern>\\d{1}</nationalNumberPattern></tollFree>
          <standardRate><nationalNumberPattern>\\d{2}</nationalNumberPattern></standardRate>
          <premiumRate><nationalNumberPattern>\\d{3}</nationalNumberPattern></premiumRate>
          <shortCode><nationalNumberPattern>\\d{4}</nationalNumberPattern></shortCode>
          <carrierSpecific>
            <nationalNumberPattern>\\d{5}</nationalNumberPattern>
          </carrierSpecific>
          <smsServices>
            <nationalNumberPattern>\\d{6}</nationalNumberPattern>
          </smsServices>
        </territory>
      </territories>
    </phoneNumberMetadata>
    """

    [metadata] = Yaphone.Metadata.parse!(xml_input, short_number: true)

    assert "\\d{1}" == metadata.toll_free.national_number_pattern
    assert "\\d{2}" == metadata.standard_rate.national_number_pattern
    assert "\\d{3}" == metadata.premium_rate.national_number_pattern
    assert "\\d{4}" == metadata.short_code.national_number_pattern
    assert "\\d{5}" == metadata.carrier_specific.national_number_pattern
    assert "\\d{6}" == metadata.sms_services.national_number_pattern
  end

  test "parse! raises if type is present multiple times" do
    xml_input = """
    <phoneNumberMetadata>
      <territories>
        <territory countryCode="33">
          <fixedLine><nationalNumberPattern>\\d{6}</nationalNumberPattern></fixedLine>
          <fixedLine><nationalNumberPattern>\\d{6}</nationalNumberPattern></fixedLine>
        </territory>
      </territories>
    </phoneNumberMetadata>
    """

    assert_raise ArgumentError, ~r/^Multiple elements with type fixedLine found/, fn ->
      Yaphone.Metadata.parse!(xml_input)
    end
  end
end
