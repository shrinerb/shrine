require "test_helper"
require "shrine/plugins/_urlsafe_serialization"

describe Shrine::Plugins::UrlsafeSerialization do
  before do
    @uploader = uploader { plugin :_urlsafe_serialization }
    @uploaded_file = @uploader.upload(fakeio)
  end

  it "serializes and deserializes" do
    serialized_file = @uploaded_file.class.urlsafe_dump(@uploaded_file)

    assert_instance_of String,             serialized_file
    refute_equal       "",                 serialized_file

    deserialized_file = @uploaded_file.class.urlsafe_load(serialized_file)

    assert_equal @uploaded_file.class,       deserialized_file.class
    assert_equal @uploaded_file.id,          deserialized_file.id
    assert_equal @uploaded_file.storage_key, deserialized_file.storage_key
    assert_equal Hash.new,                   deserialized_file.metadata
  end

  it "has class and instance method for serializing" do
    assert_equal @uploaded_file.class.urlsafe_dump(@uploaded_file),
                 @uploaded_file.urlsafe_dump
  end

  it "can include metadata" do
    @uploaded_file.metadata.merge!(
      "filename"  => "nature.jpg",
      "size"      => 123,
      "mime_type" => "image/jpeg",
    )

    serialized_file   = @uploaded_file.urlsafe_dump(metadata: %w[filename])
    deserialized_file = @uploaded_file.class.urlsafe_load(serialized_file)
    assert_equal "nature.jpg",  deserialized_file.metadata["filename"]
    assert_nil                  deserialized_file.metadata["size"]
    assert_nil                  deserialized_file.metadata["mime_type"]

    serialized_file   = @uploaded_file.urlsafe_dump(metadata: %w[filename size])
    deserialized_file = @uploaded_file.class.urlsafe_load(serialized_file)
    assert_equal "nature.jpg",  deserialized_file.metadata["filename"]
    assert_equal  123,          deserialized_file.metadata["size"]
    assert_nil                  deserialized_file.metadata["mime_type"]

    serialized_file   = @uploaded_file.urlsafe_dump(metadata: %w[filename size mime_type])
    deserialized_file = @uploaded_file.class.urlsafe_load(serialized_file)
    assert_equal "nature.jpg",  deserialized_file.metadata["filename"]
    assert_equal  123,          deserialized_file.metadata["size"]
    assert_equal  "image/jpeg", deserialized_file.metadata["mime_type"]
  end

  it "always serializes metadata in the specified order" do
    @uploaded_file.metadata.merge!(
      "filename"  => "nature.jpg",
      "size"      => 123,
      "mime_type" => "image/jpeg",
    )

    serialized_file_1   = @uploaded_file.urlsafe_dump(metadata: %w[filename size mime_type])
    deserialized_file_1 = @uploaded_file.class.urlsafe_load(serialized_file_1)

    @uploaded_file.metadata.merge!(
      "size"      => 123,
      "mime_type" => "image/jpeg",
      "filename"  => "nature.jpg",
    )

    serialized_file_2   = @uploaded_file.urlsafe_dump(metadata: %w[filename size mime_type])
    deserialized_file_2 = @uploaded_file.class.urlsafe_load(serialized_file_2)

    assert_equal serialized_file_1,                 serialized_file_2
    assert_equal deserialized_file_1.metadata.keys, deserialized_file_2.metadata.keys
  end

  it "includes metadata even if they don't exist" do
    @uploaded_file.metadata.merge!("foo" => nil)

    serialized_file   = @uploaded_file.urlsafe_dump(metadata: %w[foo bar])
    deserialized_file = @uploaded_file.class.urlsafe_load(serialized_file)

    assert_equal Hash["foo" => nil, "bar" => nil], deserialized_file.metadata
  end

  it "preserves UTF-8 characters and encoding" do
    @uploaded_file.metadata["filename"] = "øre"

    serialized_file   = @uploaded_file.urlsafe_dump(metadata: %w[filename])
    deserialized_file = @uploaded_file.class.urlsafe_load(serialized_file)

    assert_equal Encoding::UTF_8, deserialized_file.metadata["filename"].encoding
    assert_equal "øre",           deserialized_file.metadata["filename"]
  end

  it "doesn't mutate the receiver" do
    metadata = @uploaded_file.metadata.dup

    @uploaded_file.urlsafe_dump
    assert_equal metadata, @uploaded_file.metadata

    @uploaded_file.urlsafe_dump(metadata: ["bar"])
    assert_equal metadata, @uploaded_file.metadata
  end

  describe "with secret key" do
    before do
      @uploader = uploader { plugin :_urlsafe_serialization, secret_key: "secret_key" }
      @shrine = @uploader.class
      @uploaded_file = @uploader.upload(fakeio)
    end

    it "serializes and deserializes" do
      serialized_file = @uploaded_file.class.urlsafe_dump(@uploaded_file)

      assert_instance_of String, serialized_file
      refute_equal       "",     serialized_file

      deserialized_file = @uploaded_file.class.urlsafe_load(serialized_file)

      assert_equal @uploaded_file.class,       deserialized_file.class
      assert_equal @uploaded_file.id,          deserialized_file.id
      assert_equal @uploaded_file.storage_key, deserialized_file.storage_key
      assert_equal Hash.new,                   deserialized_file.metadata
    end

    it "generates same identifier for same secret key" do
      serialized_file1 = @uploaded_file.class.urlsafe_dump(@uploaded_file)
      serialized_file2 = @uploaded_file.class.urlsafe_dump(@uploaded_file)

      assert_equal serialized_file1, serialized_file2
    end

    it "generates different identifier for different secret key" do
      serialized_file1 = @uploaded_file.class.urlsafe_dump(@uploaded_file)
      @shrine.plugin :_urlsafe_serialization, secret_key: "different_key"
      serialized_file2 = @uploaded_file.class.urlsafe_dump(@uploaded_file)

      refute_equal serialized_file1, serialized_file2
    end

    it "fails when signature doesn't match" do
      serialized_file = @uploaded_file.class.urlsafe_dump(@uploaded_file)
      serialized_file = serialized_file.sub(/^\w+/, "doesn't match")

      assert_raises(Shrine::Plugins::UrlsafeSerialization::InvalidSignature) do
        @uploaded_file.class.urlsafe_load(serialized_file)
      end
    end

    it "fails when signature is missing" do
      serialized_file = @uploaded_file.class.urlsafe_dump(@uploaded_file)
      serialized_file = serialized_file.sub(/^\w+--/, "")

      assert_raises(Shrine::Plugins::UrlsafeSerialization::InvalidSignature) do
        @uploaded_file.class.urlsafe_load(serialized_file)
      end
    end
  end
end
