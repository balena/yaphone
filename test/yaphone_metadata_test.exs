defmodule YaphoneMetadataTest do
  use ExUnit.Case

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

    {intl_format, explicit_intl_defined} =
      %Yaphone.Metadata{national_prefix: "0"}
      |> Yaphone.Metadata.parse_international_format(xml_input, national_format)

    assert intl_format == nil
  end
end
