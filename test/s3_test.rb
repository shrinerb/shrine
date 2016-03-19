require "test_helper"

require "shrine/storage/s3"
require "shrine/storage/linter"

require "down"
require "securerandom"

describe Shrine::Storage::S3 do
  require "dotenv"
  Dotenv.load!

  def s3(**options)
    options[:bucket]            ||= ENV.fetch("S3_BUCKET")
    options[:region]            ||= ENV.fetch("S3_REGION")
    options[:access_key_id]     ||= ENV.fetch("S3_ACCESS_KEY_ID")
    options[:secret_access_key] ||= ENV.fetch("S3_SECRET_ACCESS_KEY")

    Shrine::Storage::S3.new(**options)
  end

  before do
    @s3 = s3
    shrine = Class.new(Shrine)
    shrine.storages = {s3: @s3}
    @uploader = shrine.new(:s3)
  end

  after do
    @s3.clear!(:confirm)
  end

  it "passes the linter" do
    Shrine::Storage::Linter.call(s3)
    Shrine::Storage::Linter.call(s3(prefix: "foo"))
  end

  describe "#upload" do
    it "copies the file if it's from also S3" do
      uploaded_file = @uploader.upload(fakeio, location: "foo")
      assert @s3.send(:copyable?, uploaded_file)
      @s3.upload(uploaded_file, "bar")
      assert @s3.exists?("bar")
    end

    it "preserves the MIME type" do
      uploaded_file = @uploader.upload(fakeio(content_type: "foo/bar"), location: "foo")
      tempfile = @s3.download("foo")
      assert_equal "foo/bar", tempfile.content_type

      @uploader.upload(uploaded_file, location: "bar")
      tempfile = @s3.download("bar")
      assert_equal "foo/bar", tempfile.content_type
    end

    it "applies upload options" do
      @s3 = s3(upload_options: {content_type: "foo/bar"})
      @s3.upload(fakeio, "foo")
      tempfile = @s3.download("foo")
      assert_equal "foo/bar", tempfile.content_type
    end

    it "accepts additional upload options via metadata" do
      @s3.upload(fakeio, "foo", {"s3" => {content_type: "foo/bar"}})
      tempfile = @s3.download("foo")
      assert_equal "foo/bar", tempfile.content_type
    end

    it "doesn't require S3 files to have a size" do
      uploaded_file = @uploader.upload(fakeio)
      uploaded_file.metadata.delete("size")
      @s3.upload(uploaded_file, "foo.jpg")
      assert @s3.exists?("foo.jpg")
    end
  end

  describe "#url" do
    it "provides a download URL for the file" do
      @s3.upload(fakeio("image"), "foo")
      downloaded = Down.download(@s3.url("foo"))
      assert_equal "image", downloaded.read
    end

    it "can provide a force download URL" do
      url = @s3.url("foo", download: true)
      assert_match "response-content-disposition=attachment", url
    end

    it "can provide a CDN url" do
      @s3 = s3(host: "http://123.cloudfront.net")
      url = @s3.url("foo bar")
      assert_equal "http://123.cloudfront.net/foo%20bar", url
    end

    it "can provide a public url" do
      url = @s3.url("foo", public: true)
      assert_equal "https://#{@s3.bucket.name}.s3-eu-west-1.amazonaws.com/foo", url
    end
  end

  describe "#presign" do
    it "returns a PresignedPost for the given id" do
      presign = @s3.presign("foo")
      refute_empty presign.url
      assert_equal "foo", presign.fields["key"]
    end

    it "accepts additional options" do
      presign = @s3.presign("foo", content_type: "image/jpeg")
      assert_equal "image/jpeg", presign.fields["Content-Type"]
    end

    it "applies upload options" do
      @s3 = s3(upload_options: {content_type: "image/jpeg"})
      presign = @s3.presign("foo")
      assert_equal "image/jpeg", presign.fields["Content-Type"]
    end

    it "gives higher precedence to options directly passed in" do
      @s3 = s3(upload_options: {content_type: "image/jpeg"})
      presign = @s3.presign("foo", content_type: "")
      assert_equal "", presign.fields["Content-Type"]
    end

    it "works with the :endpoint option" do
      s3 = s3(endpoint: "http://foo.com")
      presign = s3.presign("foo")
      assert_equal "http://#{s3.bucket.name}.foo.com", presign.url
    end
  end
end unless ENV["CI"]
