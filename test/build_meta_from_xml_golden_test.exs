defmodule BuildMetaFromXmlGoldenTest do
  use ExUnit.Case

  test "build metadata from XML golden test" do
    filename =
      Path.join([Path.dirname(__ENV__.file), "testdata", "PhoneNumberMetadataForGoldenTests.xml"])

    metadatas = Yaphone.Metadata.parse!(File.read!(filename))

    assert MetadataToJson.country_code_to_region_code(metadatas) ==
             %{1 => :GU, 54 => :AR, 247 => :AC, 979 => :"001"}
  end
end
