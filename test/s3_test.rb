require "test_helper"

require "shrine/storage/s3"
require "shrine/storage/file_system"

require "stringio"
require "cgi"
require "tmpdir"
require "fileutils"
require "uri"

describe Shrine::Storage::S3 do
  def s3(**options)
    default_options = {
      bucket: "my-bucket",
      stub_responses: true,
    }

    Shrine::Storage::S3.new(default_options.merge(options))
  end

  def filesystem
    Shrine::Storage::FileSystem.new("#{Dir.tmpdir}/shrine")
  end

  before do
    @s3 = s3
    shrine = Class.new(Shrine)
    shrine.storages = {s3: @s3, filesystem: filesystem}
    @uploader = shrine.new(:s3)
  end

  after do
    FileUtils.rm_rf("#{Dir.tmpdir}/shrine")
  end

  describe "#initialize" do
    it "raises an error when :bucket is nil" do
      assert_raises(ArgumentError) { s3(bucket: nil) }
    end

    deprecated "accepts :multipart_threshold as an Integer" do
      @s3 = s3(multipart_threshold: 5*1024*1024)
      assert_equal 5*1024*1024, @s3.instance_variable_get(:@multipart_threshold).fetch(:upload)
    end
  end

  describe "#client" do
    it "returns an Aws::S3::Client with credentials" do
      @s3 = s3(
        access_key_id:     "abc",
        secret_access_key: "xyz",
        region:            "eu-west-1",
      )
      assert_instance_of Aws::S3::Client, @s3.client
      assert_equal "abc",       @s3.client.config.access_key_id
      assert_equal "xyz",       @s3.client.config.secret_access_key
      assert_equal "eu-west-1", @s3.client.config.region
    end
  end

  describe "#bucket" do
    it "returns an Aws::S3::Bucket" do
      @s3 = s3(bucket: "my-bucket")
      assert_instance_of Aws::S3::Bucket, @s3.bucket
      assert_equal "my-bucket", @s3.bucket.name
    end
  end

  describe "#prefix" do
    it "returns the given :prefix" do
      assert_equal "foo", s3(prefix: "foo").prefix
    end
  end

  describe "#s3" do
    deprecated "returns the deprecated Aws::S3::Resource object" do
      resource = @s3.s3
      assert_instance_of Aws::S3::Resource, resource
      assert_equal resource.client, @s3.client
    end
  end

  describe "#upload" do
    describe "on IO object with size" do
      it "uploads in a single request" do
        @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
        @s3.client.stub_responses(:put_object, ->(context) {
          assert_instance_of FakeIO, context.params[:body]
          assert_equal "foo",        context.params[:key]

          @s3.client.stub_responses(:head_object)
        })
        @s3.upload(fakeio("content"), "foo")
        assert @s3.exists?("foo")
      end
    end

    describe "on file object" do
      it "uploads in a single request if small" do
        @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
        @s3.client.stub_responses(:put_object, ->(context) {
          assert_instance_of File,    context.params[:body]
          assert_equal "foo",         context.params[:key]
          assert_equal "public-read", context.params[:acl]

          @s3.client.stub_responses(:head_object)
        })
        tempfile = Tempfile.new("")
        File.write(tempfile.path, "content")
        @s3.upload(tempfile, "foo", acl: "public-read")
        assert @s3.exists?("foo")
      end

      it "uploads in multipart requests if large" do
        @s3 = s3(multipart_threshold: { upload: 5*1024*1024 })
        @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
        @s3.client.stub_responses(:create_multipart_upload, -> (context) {
          assert_equal "public-read", context.params[:acl]
          { upload_id: "upload_id" }
        })
        @s3.client.stub_responses(:complete_multipart_upload, -> (context) {
          @s3.client.stub_responses(:head_object)
        })
        tempfile = Tempfile.new("")
        File.write(tempfile.path, "a" * 5*1024*1024)
        @s3.upload(tempfile, "foo", acl: "public-read")
        assert @s3.exists?("foo")
      end
    end

    describe "on filesystem file" do
      it "uploads in a single request if small" do
        @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
        @s3.client.stub_responses(:put_object, -> (context) {
          assert_equal 0,             context.params[:body].size
          assert_equal "public-read", context.params[:acl]

          @s3.client.stub_responses(:head_object)
        })
        uploaded_file = @uploader.class.new(:filesystem).upload(fakeio(""))
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert @s3.exists?("foo")
      end

      it "uploads in multipart requests if large" do
        @s3 = s3(multipart_threshold: { upload: 5*1024*1024 })
        @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
        @s3.client.stub_responses(:create_multipart_upload, -> (context) {
          assert_equal "public-read", context.params[:acl]
          { upload_id: "upload_id" }
        })
        @s3.client.stub_responses(:complete_multipart_upload, -> (context) {
          @s3.client.stub_responses(:head_object)
        })
        uploaded_file = @uploader.class.new(:filesystem).upload(fakeio("a" * 5*1024*1024))
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert @s3.exists?("foo")
      end
    end

    describe "on S3 file" do
      it "copies in a single request if small" do
        @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
        @s3.client.stub_responses(:copy_object, -> (context) {
          assert_equal "public-read", context.params[:acl]
          @s3.client.stub_responses(:head_object)
        })
        uploaded_file = @uploader.upload(fakeio)
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert @s3.exists?("foo")
      end

      it "copies in single request if size is unknown" do
        @s3 = s3(multipart_threshold: { copy: 5*1024*1024 })
        @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
        @s3.client.stub_responses(:copy_object, -> (context) {
          @s3.client.stub_responses(:head_object)
        })
        uploaded_file = @uploader.upload(fakeio("a" * 5*1024*1024))
        uploaded_file.metadata["size"] = nil
        @s3.upload(uploaded_file, "foo")
        assert @s3.exists?("foo")
      end

      it "copies in multipart requests if large" do
        @s3 = s3(multipart_threshold: { copy: 5*1024*1024 })
        @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
        @s3.client.stub_responses(:complete_multipart_upload, -> (context) {
          @s3.client.stub_responses(:head_object)
        })
        uploaded_file = @uploader.upload(fakeio("a" * 5*1024*1024))
        @s3.upload(uploaded_file, "foo")
        assert @s3.exists?("foo")
      end
    end

    describe "on IO object without size" do
      it "uses multipart upload" do
        ios = [
          fakeio("a" * 7*1024*1024).tap { |io| io.instance_eval { undef size } },
          fakeio("a" * 7*1024*1024).tap { |io| io.instance_eval { def size; nil; end } },
        ]

        ios.each do |io|
          @s3 = s3(multipart_threshold: { upload: 5*1024*1024 })
          @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
          @s3.client.stub_responses(:create_multipart_upload, -> (context) {
            assert_equal "public-read", context.params[:acl]
            { upload_id: "upload_id" }
          })
          @s3.client.stub_responses(:upload_part, -> (context) {
            case context.params[:part_number]
            when 1 then assert_equal 5*1024*1024, context.params[:body].size
            when 2 then assert_equal 2*1024*1024, context.params[:body].size
            else        assert false, "there are more multipart parts than expected"
            end

            { etag: "etag#{context.params[:part_number]}" }
          })
          @s3.client.stub_responses(:complete_multipart_upload, -> (context) {
            expected_parts = [
              { part_number: 1, etag: "etag1" },
              { part_number: 2, etag: "etag2" },
            ]
            assert_equal expected_parts, context.params[:multipart_upload][:parts]

            @s3.client.stub_responses(:head_object)
          })
          @s3.upload(io, "foo", acl: "public-read")
          assert @s3.exists?("foo")
        end
      end

      it "works correctly for empty IO" do
        @s3 = s3
        @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
        @s3.client.stub_responses(:upload_part, -> (context) {
          assert_equal 1, context.params[:part_number]
          assert_equal 0, context.params[:body].size

          { etag: "etag" }
        })
        @s3.client.stub_responses(:complete_multipart_upload, -> (context) {
          assert_equal [{ part_number: 1, etag: "etag" }], context.params[:multipart_upload][:parts]

          @s3.client.stub_responses(:head_object)
        })
        io = fakeio("").tap { |io| io.instance_eval { undef size } }
        @s3.upload(io, "foo")
        assert @s3.exists?("foo")
      end

      it "aborts multipart upload on exceptions" do
        @s3.client.stub_responses(:create_multipart_upload, -> (context) {
          @s3.client.stub_responses(:list_multipart_uploads, uploads: [{ upload_id: "upload_id" }])
          { upload_id: "upload_id" }
        })
        @s3.client.stub_responses(:upload_part, "NetworkError")
        @s3.client.stub_responses(:abort_multipart_upload, -> (context) {
          @s3.client.stub_responses(:list_multipart_uploads, uploads: [])
        })
        @s3.client.stub_responses(:complete_multipart_upload, -> (context) {
          assert false, "multipart upload should not be completed on exception"
        })
        io = fakeio.tap { |io| io.instance_eval { undef size } }
        assert_raises(Aws::S3::Errors::NetworkError) { @s3.upload(io, "foo") }
        assert_equal [], @s3.bucket.multipart_uploads.to_a
      end

      it "propagates exception when creating multipart upload" do
        @s3.client.stub_responses(:create_multipart_upload, "NetworkError")
        io = fakeio.tap { |io| io.instance_eval { undef size } }
        assert_raises(Aws::S3::Errors::NetworkError) { @s3.upload(io, "foo") }
      end

      it "backfills size metadata if missing" do
        io = fakeio("content")
        io.instance_eval { undef size }
        uploaded_file = @uploader.upload(io)
        assert_equal 7, uploaded_file.metadata["size"]

        io = fakeio("content")
        io.instance_eval { def size; 3; end }
        uploaded_file = @uploader.upload(io)
        assert_equal 3, uploaded_file.metadata["size"]
      end
    end

    it "forwards mime_type metadata" do
      @s3.client.stub_responses(:put_object, -> (context) {
        @s3.client.stub_responses(:get_object, content_type: context.params[:content_type])
      })
      @s3.upload(fakeio, "foo", shrine_metadata: { "mime_type" => "foo/bar" })
      assert_equal "foo/bar", @s3.object("foo").get.content_type
    end

    it "forwards filename metadata" do
      @s3.client.stub_responses(:put_object, -> (context) {
        @s3.client.stub_responses(:get_object, content_disposition: context.params[:content_disposition])
      })
      @s3.upload(fakeio, "foo", shrine_metadata: { "filename" => "file.txt" })
      assert_equal "inline; filename=\"file.txt\"", @s3.object("foo").get.content_disposition
    end

    it "accepts :content_disposition with non-ASCII characters, quotes, and spaces" do
      @s3.client.stub_responses(:put_object, -> (context) {
        @s3.client.stub_responses(:get_object, content_disposition: context.params[:content_disposition])
      })
      @s3.upload(fakeio, "foo", content_disposition: 'inline; filename=""été foo bar.pdf""')
      assert_equal "inline; filename=\"\"été foo bar.pdf\"\"", CGI.unescape(@s3.object("foo").get.content_disposition)
    end

    it "applies default upload options" do
      @s3 = s3(upload_options: { content_type: "foo/bar" })
      @s3.client.stub_responses(:put_object, -> (context) {
        @s3.client.stub_responses(:get_object, content_type: context.params[:content_type])
      })
      @s3.upload(fakeio, "foo")
      assert_equal "foo/bar", @s3.object("foo").get.content_type
    end

    it "accepts custom upload options" do
      @s3.client.stub_responses(:put_object, -> (context) {
        @s3.client.stub_responses(:get_object, content_type: context.params[:content_type])
      })
      @s3.upload(fakeio, "foo", content_type: "foo/bar")
      assert_equal "foo/bar", @s3.object("foo").get.content_type
    end
  end

  describe "#download" do
    it "downloads the object to a Tempfile" do
      @s3.client.stub_responses(:get_object, body: "content")
      tempfile = @s3.download("foo")
      assert_instance_of Tempfile, tempfile
      assert_equal "content", tempfile.read
    end

    it "opens the Tempfile in binary mode" do
      tempfile = @s3.download("foo")
      assert tempfile.binmode?
    end

    it "accepts additional options" do
      @s3.client.stub_responses(:get_object, -> (context) {
        { body: context.params[:range] }
      })
      io = @s3.download("foo", range: "bytes=0-100")
      assert_equal "bytes=0-100", io.read
    end

    it "deletes the Tempfile if an error occurs while retrieving file contents" do
      @s3.client.stub_responses(:get_object, "NetworkingError")
      tempfile = Tempfile.new("")
      Tempfile.stubs(:new).returns(tempfile)
      assert_raises(Aws::S3::Errors::NetworkingError) { @s3.download("foo") }
      assert tempfile.closed?
      assert_nil tempfile.path
    end

    it "propagates failures in creating tempfiles" do
      Tempfile.stubs(:new).raises(Errno::EMFILE) # too many open files
      assert_raises(Errno::EMFILE) { @s3.download("foo") }
    end
  end

  describe "#open" do
    it "returns a Down::ChunkedIO which downloads the object" do
      @s3.client.stub_responses(:head_object, { content_length: 7 })
      @s3.client.stub_responses(:get_object, body: "content")
      io = @s3.open("foo")
      assert_instance_of Down::ChunkedIO, io
      assert_equal "content", io.read
      assert_equal 7, io.size
    end

    it "adds the S3 object to data" do
      @s3.client.stub_responses(:head_object, { content_type: "text/plain" })
      io = @s3.open("foo")
      assert_instance_of Aws::S3::Object, io.data[:object]
      assert_equal      "text/plain",     io.data[:object].content_type
    end

    it "accepts additional options" do
      @s3.client.stub_responses(:get_object, -> (context) {
        { body: context.params[:range] }
      })
      io = @s3.open("foo", range: "bytes=0-100")
      assert_equal "bytes=0-100", io.read
    end
  end

  describe "#exists?" do
    it "returns true when object exists" do
      @s3.client.stub_responses(:head_object)
      assert_equal true, @s3.exists?("foo")
    end

    it "returns true when object doesn't exist" do
      @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
      assert_equal false, @s3.exists?("foo")
    end
  end

  describe "#url" do
    it "returns an URL to the object" do
      url = @s3.url("foo")
      assert_equal "my-bucket.s3.us-stubbed-1.amazonaws.com", URI(url).host
      refute_nil URI(url).query
    end

    it "accepts :public for public links" do
      url = @s3.url("foo", public: true)
      assert_equal "my-bucket.s3.us-stubbed-1.amazonaws.com", URI(url).host
      assert_nil URI(url).query
    end

    it "accepts :download for a forced-download link" do
      url = @s3.url("foo", download: true)
      assert_includes URI(url).query, "response-content-disposition=attachment"
    end

    it "accepts :host for specifying CDN links" do
      url = s3.url("foo/bar quux", host: "http://123.cloudfront.net")
      assert_match "http://123.cloudfront.net/foo/bar%20quux", url
      refute_nil URI(url).query

      url = s3.url("foo/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/foo/bar%20quux", url

      url = s3(bucket: "my.bucket").url("foo/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/foo/bar%20quux", url

      url = s3(force_path_style: true).url("foo/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/foo/bar%20quux", url

      url = s3(force_path_style: true).url("my-bucket/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/my-bucket/bar%20quux", url

      url = s3.url("my-bucket/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/my-bucket/bar%20quux", url
    end

    it "encodes non-ASCII characters, quotes, and spaces in :content_disposition" do
      url = @s3.url("foo", response_content_disposition: 'inline; filename=""été foo bar.pdf""')
      unescaped_query = CGI.unescape(URI(url).query.force_encoding("UTF-8"))
      assert_includes unescaped_query, 'filename="%22%C3%A9t%C3%A9 foo bar.pdf%22"'
      assert_includes CGI.unescape(unescaped_query), "inline; filename=\"\"été foo bar.pdf\"\""
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

    it "applies default upload options" do
      @s3 = s3(upload_options: {content_type: "image/jpeg"})
      presign = @s3.presign("foo")
      assert_equal "image/jpeg", presign.fields["Content-Type"]
    end

    it "works with the :endpoint option" do
      s3 = s3(endpoint: "http://foo.com")
      presign = s3.presign("foo")
      assert_equal "http://my-bucket.foo.com", presign.url
    end
  end

  describe "#delete" do
    it "deletes the object" do
      @s3.client.stub_responses(:head_object)
      @s3.client.stub_responses(:delete_object, -> (context) {
        @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
      })
      @s3.delete("foo")
      refute @s3.exists?("foo")
    end
  end

  describe "#clear!" do
    it "deletes all objects in the bucket" do
      deleted_keys = []
      @s3.client.stub_responses(:list_objects, contents: [{ key: "foo" }])
      @s3.client.stub_responses(:delete_objects, -> (context) {
        deleted_keys.concat(context.params[:delete][:objects].map { |o| o[:key] })
      })
      @s3.clear!
      assert_equal ["foo"], deleted_keys
    end

    it "deletes subset of objects in the bucket" do
      deleted_keys = []
      @s3.client.stub_responses(:list_objects, contents: [{ key: "foo"}, { key: "bar" }])
      @s3.client.stub_responses(:delete_objects, -> (context) {
        deleted_keys.concat(context.params[:delete][:objects].map { |o| o[:key] })
      })
      @s3.clear! { |object| object.key == "bar" }
      assert_equal ["bar"], deleted_keys
    end
  end

  describe "#object" do
    it "returns an Aws::S3::Object" do
      object = @s3.object("foo")
      assert_equal "foo", object.key
      assert_equal @s3.bucket.name, object.bucket.name
    end

    it "applies the :prefix" do
      object = s3(prefix: "foo").object("bar")
      assert_equal "foo/bar", object.key
    end
  end

  describe "#method_missing" do
    deprecated "implements #stream" do
      @s3.client.stub_responses(:head_object, content_length: 7)
      @s3.client.stub_responses(:get_object, body: "content")
      assert_equal [["content", 7]], @s3.enum_for(:stream, "foo").to_a
    end

    it "calls super for other methods" do
      assert_raises(NoMethodError) { @s3.foo }
    end
  end
end
