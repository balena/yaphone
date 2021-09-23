defmodule MetadataToJson do
  def country_code_to_region_code(metadatas) do
    metadatas
    |> Enum.map(fn %{id: id, country_code: country_code} -> {country_code, id} end)
    |> Map.new()
  end

  def country_to_metadata(metadatas) do
    metadatas
    |> Enum.map(fn meta ->
      key =
        if meta.id == :"001" do
          meta.country_code
        else
          meta.id
        end

      {to_string(key), metadata_to_list(meta)}
    end)
    |> Map.new()
  end

  defp number_format_to_list(format) do
    [
      # missing 0
      nil,
      # required string pattern = 1;
      format.pattern,
      # required string format = 2;
      format.format,
      # repeated string leading_digits_pattern = 3;
      format.leading_digits_pattern,
      # optional string national_prefix_formatting_rule = 4;
      format.national_prefix_formatting_rule,
      # optional string domestic_carrier_code_formatting_rule = 5;
      format.domestic_carrier_code_formatting_rule,
      # optional bool national_prefix_optional_when_formatting = 6 [default = false];
      format.national_prefix_optional_when_formatting
    ]
    |> simplify_list()
  end

  defp phone_number_desc_to_list(nil), do: nil

  defp phone_number_desc_to_list(desc) do
    [
      # missing 0
      nil,
      # missing 1
      nil,
      # optional string national_number_pattern = 2;
      desc.national_number_pattern,
      # missing 3
      nil,
      # missing 4
      nil,
      # missing 5
      nil,
      # optional string example_number = 6;
      desc.example_number,
      # missing 7
      nil,
      # missing 8
      nil,
      # repeated int32 possible_length = 9;
      desc.possible_length,
      # repeated int32 possible_length_local_only = 10;
      desc.possible_length_local_only
    ]
    |> simplify_list()
  end

  defp metadata_to_list(metadata) do
    [
      # missing 0
      nil,
      # optional PhoneNumberDesc general_desc = 1;
      phone_number_desc_to_list(metadata.general_desc),
      # optional PhoneNumberDesc fixed_line = 2;
      phone_number_desc_to_list(metadata.fixed_line),
      # optional PhoneNumberDesc mobile = 3;
      phone_number_desc_to_list(metadata.mobile),
      # optional PhoneNumberDesc toll_free = 4;
      phone_number_desc_to_list(metadata.toll_free),
      # optional PhoneNumberDesc premium_rate = 5;
      phone_number_desc_to_list(metadata.premium_rate),
      # optional PhoneNumberDesc shared_cost = 6;
      phone_number_desc_to_list(metadata.shared_cost),
      # optional PhoneNumberDesc personal_number = 7;
      phone_number_desc_to_list(metadata.personal_number),
      # optional PhoneNumberDesc voip = 8;
      phone_number_desc_to_list(metadata.voip),
      # required string id = 9;
      metadata.id,
      # optional int32 country_code = 10;
      metadata.country_code,
      # optional string international_prefix = 11;
      metadata.international_prefix,
      # optional string national_prefix = 12;
      metadata.national_prefix,
      # optional string preferred_extn_prefix = 13;
      metadata.preferred_extn_prefix,
      # missing 14
      nil,
      # optional string national_prefix_for_parsing = 15;
      metadata.national_prefix_for_parsing,
      # optional string national_prefix_transform_rule = 16;
      metadata.national_prefix_transform_rule,
      # optional string preferred_international_prefix = 17;
      metadata.preferred_international_prefix,
      # optional bool same_mobile_and_fixed_line_pattern = 18 [default=false];
      if(metadata.same_mobile_and_fixed_line_pattern, do: 1, else: nil),
      # repeated NumberFormat number_format = 19;
      for(nf <- metadata.number_format, do: number_format_to_list(nf)),
      # repeated NumberFormat intl_number_format = 20;
      for(nf <- metadata.intl_number_format, do: number_format_to_list(nf)),
      # optional PhoneNumberDesc pager = 21;
      phone_number_desc_to_list(metadata.pager),
      # optional bool main_country_for_code = 22 [default=false];
      if(metadata.main_country_for_code, do: 1, else: nil),
      # optional string leading_digits = 23;
      metadata.leading_digits,
      # optional PhoneNumberDesc no_international_dialing = 24;
      phone_number_desc_to_list(metadata.no_international_dialing),
      # optional PhoneNumberDesc uan = 25;
      phone_number_desc_to_list(metadata.uan),
      # optional bool leading_zero_possible = 26 [default=false];
      if(metadata.leading_zero_possible, do: 1, else: nil),
      # optional PhoneNumberDesc emergency = 27;
      phone_number_desc_to_list(metadata.emergency),
      # optional PhoneNumberDesc voicemail = 28;
      phone_number_desc_to_list(metadata.voicemail),
      # optional PhoneNumberDesc short_code = 29;
      phone_number_desc_to_list(metadata.short_code),
      # optional PhoneNumberDesc standard_rate = 30;
      phone_number_desc_to_list(metadata.standard_rate),
      # optional PhoneNumberDesc carrier_specific = 31;
      phone_number_desc_to_list(metadata.carrier_specific),
      # optional bool mobile_number_portable_region = 32 [default=false];
      # left as null because this data is not used in the current JS API's.
      nil,
      # optional PhoneNumberDesc sms_services = 33;
      phone_number_desc_to_list(metadata.sms_services)
    ]
    |> simplify_list()
  end

  defp simplify_list(list) do
    list
    |> Enum.map(fn
      [] -> nil
      [%{source: _} | _] = regexes -> for r <- regexes, do: r.source
      atom when is_atom(atom) and atom != nil -> to_string(atom)
      %{source: source} -> source
      other -> other
    end)
  end
end
