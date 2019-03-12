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
    Shrine::Storage::S3.new(bucket: "my-bucket", stub_responses: true, **options)
  end

  before do
    @s3 = s3
    @shrine = Class.new(Shrine)
    @shrine.storages = { s3: @s3 }
    @uploader = @shrine.new(:s3)
  end

  describe "#initialize" do
    it "raises an appropriate error when :bucket is nil" do
      error = assert_raises(ArgumentError) { s3(bucket: nil) }
      assert_match "the :bucket option is nil", error.message
    end

    it "accepts :client" do
      client = Aws::S3::Encryption::Client.new(encryption_key: "a" * 16, stub_responses: true)
      @s3 = s3(client: client)
      assert_equal client, @s3.client
      assert_equal client, @s3.bucket.client
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
        @s3.upload(fakeio("content"), "foo", acl: "public-read")
        assert_equal 1, @s3.client.api_requests.size

        assert_equal :put_object,   @s3.client.api_requests[0][:operation_name]
        assert_instance_of FakeIO,  @s3.client.api_requests[0][:params][:body]
        assert_equal "foo",         @s3.client.api_requests[0][:params][:key]
        assert_equal "public-read", @s3.client.api_requests[0][:params][:acl]
      end

      it "respects :prefix" do
        @s3 = s3(prefix: "prefix")
        @s3.upload(fakeio, "foo")
        assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
      end
    end

    describe "on file object" do
      it "uploads in a single request if small" do
        @s3.upload(tempfile("content"), "foo", acl: "public-read")
        assert_equal 1, @s3.client.api_requests.size

        assert_equal :put_object,   @s3.client.api_requests[0][:operation_name]
        assert_instance_of File,    @s3.client.api_requests[0][:params][:body]
        assert_equal "foo",         @s3.client.api_requests[0][:params][:key]
        assert_equal "public-read", @s3.client.api_requests[0][:params][:acl]
      end

      it "uploads in multipart requests if large" do
        @s3 = s3(multipart_threshold: { upload: 5*1024*1024 })
        @s3.upload(tempfile("a" * 6*1024*1024), "foo", acl: "public-read")
        assert_equal 4, @s3.client.api_requests.size

        assert_equal :create_multipart_upload,   @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[0][:params][:key]
        assert_equal "public-read",              @s3.client.api_requests[0][:params][:acl]

        assert_equal :upload_part,               @s3.client.api_requests[1][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[1][:params][:key]

        assert_equal :upload_part,               @s3.client.api_requests[2][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[2][:params][:key]

        assert_equal :complete_multipart_upload, @s3.client.api_requests[3][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[3][:params][:key]
      end unless RUBY_ENGINE == "jruby" # randomly fails on JRuby

      it "respects :prefix" do
        @s3 = s3(prefix: "prefix")
        @s3.upload(tempfile("content"), "foo")
        assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
      end
    end

    describe "on filesystem file" do
      before do
        @shrine.storages[:filesystem] = Shrine::Storage::FileSystem.new("#{Dir.tmpdir}/shrine")
      end

      after do
        FileUtils.rm_rf("#{Dir.tmpdir}/shrine")
      end

      it "uploads in a single request if small" do
        uploaded_file = @shrine.new(:filesystem).upload(fakeio)
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert_equal 1, @s3.client.api_requests.size

        assert_equal :put_object,   @s3.client.api_requests[0][:operation_name]
        assert_instance_of File,    @s3.client.api_requests[0][:params][:body]
        assert_equal "foo",         @s3.client.api_requests[0][:params][:key]
        assert_equal "public-read", @s3.client.api_requests[0][:params][:acl]
      end

      it "uploads in multipart requests if large" do
        @s3 = s3(multipart_threshold: { upload: 5*1024*1024 })
        uploaded_file = @shrine.new(:filesystem).upload(fakeio("a" * 6*1024*1024))
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert_equal 4, @s3.client.api_requests.size

        assert_equal :create_multipart_upload,   @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[0][:params][:key]
        assert_equal "public-read",              @s3.client.api_requests[0][:params][:acl]

        assert_equal :upload_part,               @s3.client.api_requests[1][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[1][:params][:key]

        assert_equal :upload_part,               @s3.client.api_requests[2][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[2][:params][:key]

        assert_equal :complete_multipart_upload, @s3.client.api_requests[3][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[3][:params][:key]
      end unless RUBY_ENGINE == "jruby" # randomly fails on JRuby

      it "respects :prefix" do
        @s3 = s3(prefix: "prefix")
        uploaded_file = @shrine.new(:filesystem).upload(fakeio)
        @s3.upload(uploaded_file, "foo")
        assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
      end
    end

    describe "on S3 file" do
      it "copies in a single request if small" do
        uploaded_file = @shrine.uploaded_file("id"=>"bar", "storage"=>"s3", "metadata"=>{"size"=>10})
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert_equal 1, @s3.client.api_requests.size

        assert_equal :copy_object,    @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",           @s3.client.api_requests[0][:params][:key]
        assert_equal "my-bucket/bar", @s3.client.api_requests[0][:params][:copy_source]
        assert_equal "public-read",   @s3.client.api_requests[0][:params][:acl]
      end

      it "copies in single request if size is unknown" do
        uploaded_file = @shrine.uploaded_file("id"=>"bar", "storage"=>"s3")
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert_equal 1, @s3.client.api_requests.size

        assert_equal :copy_object,    @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",           @s3.client.api_requests[0][:params][:key]
        assert_equal "my-bucket/bar", @s3.client.api_requests[0][:params][:copy_source]
        assert_equal "public-read",   @s3.client.api_requests[0][:params][:acl]
      end

      it "copies in multipart requests if large" do
        @s3 = s3(multipart_threshold: { copy: 5*1024*1024 })
        uploaded_file = @shrine.uploaded_file("id"=>"bar", "storage"=>"s3", "metadata"=>{"size"=>6*1024*1024})
        @s3.upload(uploaded_file, "foo", acl: "public-read", min_part_size: 5*1024*1024)
        assert_equal 4, @s3.client.api_requests.size

        assert_equal :create_multipart_upload,   @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[0][:params][:key]
        assert_equal "public-read",              @s3.client.api_requests[0][:params][:acl]

        assert_equal :upload_part_copy,          @s3.client.api_requests[1][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[1][:params][:key]
        assert_equal "my-bucket/bar",            @s3.client.api_requests[1][:params][:copy_source]

        assert_equal :upload_part_copy,          @s3.client.api_requests[2][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[2][:params][:key]
        assert_equal "my-bucket/bar",            @s3.client.api_requests[2][:params][:copy_source]

        assert_equal :complete_multipart_upload, @s3.client.api_requests[3][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[3][:params][:key]
      end

      it "works with object from other storage" do
        @shrine.storages[:other_s3] = s3(bucket: "other-bucket", prefix: "prefix")
        uploaded_file = @shrine.uploaded_file("id"=>"bar", "storage"=>"other_s3")
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert_equal 1, @s3.client.api_requests.size

        assert_equal :copy_object,              @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",                     @s3.client.api_requests[0][:params][:key]
        assert_equal "other-bucket/prefix/bar", @s3.client.api_requests[0][:params][:copy_source]
        assert_equal "public-read",             @s3.client.api_requests[0][:params][:acl]
      end

      it "respects :prefix" do
        @s3 = s3(prefix: "prefix")
        uploaded_file = @shrine.uploaded_file("id"=>"bar", "storage"=>"s3")
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert_equal :copy_object, @s3.client.api_requests[0][:operation_name]
        assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
      end
    end

    describe "on other uploaded file" do
      before do
        @shrine.storages[:test] = Shrine::Storage::Test.new
      end

      it "uploads in a single request" do
        uploaded_file = @shrine.new(:test).upload(fakeio)
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert_equal 1, @s3.client.api_requests.size
        assert_equal :put_object,   @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",         @s3.client.api_requests[0][:params][:key]
        assert_equal uploaded_file, @s3.client.api_requests[0][:params][:body]
      end

      it "respects :prefix" do
        uploaded_file = @shrine.new(:test).upload(fakeio)
        @s3 = s3(prefix: "prefix")
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert_equal :put_object,  @s3.client.api_requests[0][:operation_name]
        assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
      end
    end

    describe "on IO object with unknown size" do
      it "uses multipart upload" do
        ios = [
          fakeio("a" * 6*1024*1024).tap { |io| io.instance_eval { undef size } },
          fakeio("a" * 6*1024*1024).tap { |io| io.instance_eval { def size; nil; end } },
        ]

        ios.each do |io|
          @s3 = s3
          @s3.upload(io, "foo", acl: "public-read")
          assert_equal 4, @s3.client.api_requests.size

          assert_equal :create_multipart_upload,   @s3.client.api_requests[0][:operation_name]
          assert_equal "foo",                      @s3.client.api_requests[0][:params][:key]
          assert_equal "public-read",              @s3.client.api_requests[0][:params][:acl]

          assert_equal :upload_part,               @s3.client.api_requests[1][:operation_name]
          assert_equal "foo",                      @s3.client.api_requests[1][:params][:key]

          assert_equal :upload_part,               @s3.client.api_requests[2][:operation_name]
          assert_equal "foo",                      @s3.client.api_requests[2][:params][:key]

          assert_equal :complete_multipart_upload, @s3.client.api_requests[3][:operation_name]
          assert_equal "foo",                      @s3.client.api_requests[3][:params][:key]
        end
      end unless RUBY_ENGINE == "jruby" # randomly fails on JRuby

      it "aborts multipart upload on exceptions" do
        @s3.client.stub_responses(:create_multipart_upload, { upload_id: "upload_id" })
        @s3.client.stub_responses(:upload_part, "NetworkError")
        io = fakeio.tap { |io| io.instance_eval { undef size } }
        assert_raises(Aws::S3::MultipartUploadError) { @s3.upload(io, "foo") }
        assert_equal 3, @s3.client.api_requests.size

        assert_equal :create_multipart_upload,   @s3.client.api_requests[0][:operation_name]

        assert_equal :upload_part,               @s3.client.api_requests[1][:operation_name]

        assert_equal :abort_multipart_upload,    @s3.client.api_requests[2][:operation_name]
        assert_equal "upload_id",                @s3.client.api_requests[2][:params][:upload_id]
      end

      it "propagates exceptions when creating multipart upload" do
        @s3.client.stub_responses(:create_multipart_upload, "NetworkError")
        io = fakeio.tap { |io| io.instance_eval { undef size } }
        assert_raises(Aws::S3::Errors::NetworkError) { @s3.upload(io, "foo") }
      end

      it "backfills size metadata if missing" do
        io = fakeio("content").tap { |io| io.instance_eval { undef size } }
        uploaded_file = @uploader.upload(io)
        assert_equal 7, uploaded_file.metadata["size"]

        # doesn't override existing size
        io = fakeio("content").tap { |io| io.instance_eval { def size; 3; end } }
        uploaded_file = @uploader.upload(io)
        assert_equal 3, uploaded_file.metadata["size"]
      end

      it "respects :prefix" do
        @s3 = s3(prefix: "prefix")
        @s3.upload(fakeio, "foo")
        assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
      end

      it "respects :public" do
        @s3 = s3(public: true)

        @s3.upload(fakeio, "foo")
        assert_equal "public-read", @s3.client.api_requests[0][:params][:acl]

        @s3.upload(fakeio, "foo", acl: "public-read-write")
        assert_equal "public-read-write", @s3.client.api_requests[1][:params][:acl]
      end
    end

    it "forwards mime_type metadata" do
      @s3.upload(fakeio, "foo", shrine_metadata: { "mime_type" => "foo/bar" })
      assert_equal "foo/bar", @s3.client.api_requests[0][:params][:content_type]
    end

    it "forwards filename metadata" do
      @s3.upload(fakeio, "foo", shrine_metadata: { "filename" => "file.txt" })
      assert_equal ContentDisposition.inline("file.txt"), @s3.client.api_requests[0][:params][:content_disposition]
    end

    deprecated "accepts :content_disposition with non-ASCII characters, quotes, and spaces" do
      @s3.upload(fakeio, "foo", content_disposition: 'inline; filename=""été foo bar.pdf""')
      assert_equal "inline; filename=\"\"été foo bar.pdf\"\"", CGI.unescape(@s3.client.api_requests[0][:params][:content_disposition])
    end

    it "applies default upload options" do
      @s3 = s3(upload_options: { content_type: "foo/bar" })
      @s3.upload(fakeio, "foo")
      assert_equal "foo/bar", @s3.client.api_requests[0][:params][:content_type]
    end

    it "accepts custom upload options" do
      @s3.upload(fakeio, "foo", content_type: "foo/bar")
      assert_equal "foo/bar", @s3.client.api_requests[0][:params][:content_type]
    end
  end

  describe "#open" do
    it "returns a Down::ChunkedIO which downloads the object" do
      @s3.client.stub_responses(:get_object, body: "content")
      io = @s3.open("foo")
      assert_instance_of Down::ChunkedIO, io
      assert_equal "content", io.read
    end

    it "retrieves the content length" do
      @s3.client.stub_responses(:head_object, content_length: 44)
      io = @s3.open("foo")
      assert_equal 44, io.size
    end

    it "makes one #get_object and one #head_object request" do
      @s3.open("foo")
      assert_equal 2, @s3.client.api_requests.count
      assert_equal :head_object, @s3.client.api_requests[0][:operation_name]
      assert_equal "foo",        @s3.client.api_requests[0][:params][:key]
      assert_equal :get_object,  @s3.client.api_requests[1][:operation_name]
      assert_equal "foo",        @s3.client.api_requests[1][:params][:key]
    end

    it "returns the Aws::S3::Object in data" do
      @s3.client.stub_responses(:head_object, { content_type: "text/plain" })
      io = @s3.open("foo")
      assert_instance_of Aws::S3::Object, io.data[:object]
      assert_equal "text/plain", io.data[:object].content_type
      assert_equal 2, @s3.client.api_requests.count
    end

    it "accepts :rewindable option" do
      @s3.client.stub_responses(:get_object, body: "content")
      io = @s3.open("foo", rewindable: false)
      assert_raises(IOError) { io.rewind }
    end

    it "forwards additional options to both #get_object and #head_object" do
      io = @s3.open("foo", range: "bytes=0-100", response_content_encoding: "gzip")
      assert_equal :head_object,  @s3.client.api_requests[0][:operation_name]
      assert_equal "bytes=0-100", @s3.client.api_requests[0][:params][:range]
      assert_nil                  @s3.client.api_requests[0][:params][:response_content_encoding]
      assert_equal :get_object,   @s3.client.api_requests[1][:operation_name]
      assert_equal "bytes=0-100", @s3.client.api_requests[1][:params][:range]
      assert_equal "gzip",        @s3.client.api_requests[1][:params][:response_content_encoding]
    end

    it "respects :prefix" do
      @s3 = s3(prefix: "prefix")
      @s3.open("foo")
      assert_equal :head_object, @s3.client.api_requests[0][:operation_name]
      assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
      assert_equal :get_object,  @s3.client.api_requests[1][:operation_name]
      assert_equal "prefix/foo", @s3.client.api_requests[1][:params][:key]
    end
  end

  describe "#exists?" do
    it "returns true when object exists" do
      @s3.client.stub_responses(:head_object, status_code: 200, body: "", headers: {})
      assert_equal true, @s3.exists?("foo")
    end

    it "returns true when object doesn't exist" do
      @s3.client.stub_responses(:head_object, status_code: 404, body: "", headers: {})
      assert_equal false, @s3.exists?("foo")
    end

    it "respects :prefix" do
      @s3 = s3(prefix: "prefix")
      @s3.exists?("foo")
      assert_equal :head_object, @s3.client.api_requests[0][:operation_name]
      assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
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
      url = s3(bucket: "my-bucket").url("foo/bar quux", host: "http://123.cloudfront.net")
      assert_match "http://123.cloudfront.net/foo/bar%20quux", url
      refute_nil URI.parse(url).query

      url = s3(bucket: "my-bucket").url("foo/bar quux", host: "http://123.cloudfront.net/")
      assert_match "http://123.cloudfront.net/foo/bar%20quux", url
      refute_nil URI.parse(url).query

      url = s3(bucket: "my-bucket").url("foo/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/foo/bar%20quux", url

      url = s3(bucket: "my-bucket").url("my-bucket/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/my-bucket/bar%20quux", url

      url = s3(bucket: "my.bucket").url("foo/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/foo/bar%20quux", url

      url = s3(bucket: "my.bucket").url("my.bucket/foo/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/my.bucket/foo/bar%20quux", url

      url = s3(bucket: "my-bucket", force_path_style: true).url("foo/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/foo/bar%20quux", url

      url = s3(bucket: "my-bucket", force_path_style: true).url("my-bucket/foo/bar quux", host: "http://123.cloudfront.net", public: true)
      assert_equal "http://123.cloudfront.net/my-bucket/foo/bar%20quux", url

      url = s3(bucket: "my-bucket").url("foo/bar quux", host: "http://123.cloudfront.net/my-bucket/", public: true)
      assert_equal "http://123.cloudfront.net/my-bucket/foo/bar%20quux", url

      url = s3(bucket: "my-bucket").url("foo/bar quux", host: "http://123.cloudfront.net/prefix/", public: true)
      assert_equal "http://123.cloudfront.net/prefix/foo/bar%20quux", url
    end

    it "uses the custom signer" do
      @s3 = s3(signer: -> (url, **options) { "#{url}?#{options.map{|k,v|"#{k}=#{v}"}.join("&")}" })

      url = @s3.url("foo", bar: "baz")
      assert_equal "https://my-bucket.s3.us-stubbed-1.amazonaws.com/foo?bar=baz", url

      url = @s3.url("foo", host: "https://123.cloudfront.net", bar: "baz")
      assert_equal "https://123.cloudfront.net/foo?bar=baz", url
    end

    deprecated "encodes non-ASCII characters, quotes, and spaces in :content_disposition" do
      url = @s3.url("foo", response_content_disposition: 'inline; filename=""été foo bar.pdf""')
      unescaped_query = CGI.unescape(URI(url).query.force_encoding("UTF-8"))
      assert_includes unescaped_query, 'filename="%22%C3%A9t%C3%A9 foo bar.pdf%22"'
      assert_includes CGI.unescape(unescaped_query), "inline; filename=\"\"été foo bar.pdf\"\""
    end
  end

  describe "#presign" do
    it "returns POST request data for the given id" do
      data = @s3.presign("foo")
      assert_equal :post, data[:method]
      assert_match /^http/, data[:url]
      assert_equal "foo", data[:fields]["key"]
    end

    it "accepts additional options" do
      data = @s3.presign("foo", content_type: "image/jpeg")
      assert_equal "image/jpeg", data[:fields]["Content-Type"]
    end

    it "applies default upload options" do
      @s3 = s3(upload_options: { content_type: "image/jpeg" })
      data = @s3.presign("foo")
      assert_equal "image/jpeg", data[:fields]["Content-Type"]
    end

    it "works with the :endpoint option" do
      @s3 = s3(endpoint: "http://foo.com")
      data = @s3.presign("foo")
      assert_equal "http://my-bucket.foo.com", data[:url]
    end

    it "can generate parameters for PUT method" do
      data = @s3.presign("foo", method: :put)
      assert_equal :put, data[:method]
      assert_includes data[:url], "X-Amz-Signature"
    end

    it "adds required headers for PUT method" do
      data = @s3.presign "foo",
        method: :put,
        content_length:      1,
        content_type:        "text/plain",
        content_disposition: "attachment",
        content_encoding:    "gzip",
        content_language:    "en-US",
        content_md5:         "foo"

      expected_headers = {
        "Content-Length"       => 1,
        "Content-Type"         => "text/plain",
        "Content-Disposition"  => "attachment",
        "Content-Encoding"     => "gzip",
        "Content-Language"     => "en-US",
        "Content-MD5"          => "foo"
      }

      assert_equal expected_headers, data[:headers]
    end

    it "respects :prefix" do
      @s3 = s3(prefix: "prefix")

      data = @s3.presign("foo")
      assert_equal "prefix/foo", data[:fields]["key"]

      data = @s3.presign("foo", method: :put)
      assert_equal "/prefix/foo", URI(data[:url]).path
    end

    it "respects :public" do
      @s3 = s3(public: true)

      data = @s3.presign("foo")
      assert_equal "public-read", data[:fields]["acl"]

      data = @s3.presign("foo", method: :put)
      assert_includes data[:url], "x-amz-acl=public-read"
    end
  end

  describe "#delete" do
    it "deletes the object" do
      @s3.delete("foo")
      assert_equal 1, @s3.client.api_requests.size

      assert_equal :delete_object, @s3.client.api_requests[0][:operation_name]
      assert_equal "foo",          @s3.client.api_requests[0][:params][:key]
    end
  end

  describe "#clear!" do
    it "deletes all objects in the bucket" do
      @s3.client.stub_responses(:list_objects, contents: [{ key: "foo" }])
      @s3.clear!
      assert_equal :list_objects,    @s3.client.api_requests[0][:operation_name]
      assert_equal "my-bucket",      @s3.client.api_requests[0][:params][:bucket]
      assert_equal :delete_objects,  @s3.client.api_requests[1][:operation_name]
      assert_equal [{ key: "foo" }], @s3.client.api_requests[1][:params][:delete][:objects]
    end

    it "deletes subset of objects in the bucket" do
      @s3.client.stub_responses(:list_objects, contents: [{ key: "foo" }, { key: "bar" }])
      @s3.clear! { |object| object.key == "bar" }
      assert_equal :list_objects,    @s3.client.api_requests[0][:operation_name]
      assert_equal "my-bucket",      @s3.client.api_requests[0][:params][:bucket]
      assert_equal :delete_objects,  @s3.client.api_requests[1][:operation_name]
      assert_equal [{ key: "bar" }], @s3.client.api_requests[1][:params][:delete][:objects]
    end

    it "respects :prefix" do
      @s3 = s3(prefix: "prefix")
      @s3.client.stub_responses(:list_objects, contents: [{ key: "prefix/foo" }])
      @s3.clear!
      assert_equal :list_objects,           @s3.client.api_requests[0][:operation_name]
      assert_equal "prefix",                @s3.client.api_requests[0][:params][:prefix]
      assert_equal :delete_objects,         @s3.client.api_requests[1][:operation_name]
      assert_equal [{ key: "prefix/foo" }], @s3.client.api_requests[1][:params][:delete][:objects]
    end
  end

  describe "#object" do
    it "returns an Aws::S3::Object" do
      object = @s3.object("foo")
      assert_equal "foo", object.key
      assert_equal @s3.bucket.name, object.bucket.name
    end

    it "applies the :prefix" do
      @s3 = s3(prefix: "prefix")
      assert_equal "prefix/bar", @s3.object("bar").key
    end
  end

  describe "#method_missing" do
    describe "#stream" do
      deprecated "yields downloaded content" do
        @s3.client.stub_responses(:head_object, content_length: 7)
        @s3.client.stub_responses(:get_object, body: "content")
        assert_equal [["content", 7]], @s3.enum_for(:stream, "foo").to_a
      end
    end

    describe "#download" do
      deprecated "downloads the object to a Tempfile" do
        @s3.client.stub_responses(:get_object, body: "content")
        tempfile = @s3.download("foo")
        assert_kind_of Tempfile, tempfile
        assert_equal "content", tempfile.read
      end

      deprecated "opens the Tempfile in binary mode" do
        tempfile = @s3.download("foo")
        assert tempfile.binmode?
      end

      deprecated "makes a single #get_object API call" do
        @s3.download("foo")
        assert_equal 1, @s3.client.api_requests.count
        assert_equal :get_object, @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",       @s3.client.api_requests[0][:params][:key]
      end

      deprecated "forwards additional options to #get_object" do
        @s3.download("foo", range: "bytes=0-100")
        assert_equal :get_object,   @s3.client.api_requests[0][:operation_name]
        assert_equal "bytes=0-100", @s3.client.api_requests[0][:params][:range]
      end

      deprecated "respects :prefix" do
        @s3 = s3(prefix: "prefix")
        @s3.download("foo")
        assert_equal :get_object,  @s3.client.api_requests[0][:operation_name]
        assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
      end

      deprecated "deletes the Tempfile if an error occurs while retrieving file contents" do
        @s3.client.stub_responses(:get_object, "NetworkingError")
        tempfile = Tempfile.new
        Tempfile.stubs(:new).returns(tempfile)
        assert_raises(Aws::S3::Errors::NetworkingError) { @s3.download("foo") }
        assert tempfile.closed?
        assert_nil tempfile.path
      end

      deprecated "propagates failures in creating tempfiles" do
        Tempfile.stubs(:new).raises(Errno::EMFILE) # too many open files
        assert_raises(Errno::EMFILE) { @s3.download("foo") }
      end
    end

    it "calls super for other methods" do
      assert_raises(NoMethodError) { @s3.foo }
    end
  end
end
