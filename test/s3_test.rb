exit unless ARGV.select{|arg| File.exists?(arg)} == ["test/s3_test.rb"]

require "test_helper"

require "shrine/storage/s3"
require "shrine/storage/linter"
require "down"

require "dotenv"
Dotenv.load!

describe Shrine::Storage::S3 do
  def s3(**options)
    options[:bucket]            ||= ENV["S3_BUCKET"]
    options[:region]            ||= ENV["S3_REGION"]
    options[:access_key_id]     ||= ENV["S3_ACCESS_KEY_ID"]
    options[:secret_access_key] ||= ENV["S3_SECRET_ACCESS_KEY"]

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
    Shrine::Storage::Linter.call(s3(prefix: "store"))
  end

  describe "#upload" do
    it "copies the file if it's from also S3" do
      uploaded_file = @uploader.upload(fakeio, {location: "foo"})

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
  end

  describe "#multi_delete" do
    it "deletes multiple files at once" do
      @s3.upload(fakeio, "foo")
      @s3.upload(fakeio, "bar")

      @s3.multi_delete(["foo", "bar"])

      refute @s3.exists?("foo")
      refute @s3.exists?("bar")
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
      url = @s3.url("foo")

      assert_equal "http://123.cloudfront.net/foo", url
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
  end
end
