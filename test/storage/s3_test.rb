require "test_helper"
require "shrine/storage/s3"
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

  describe "#upload" do
    describe "simple upload" do
      it "is performed on IO with size under multipart threshold" do
        @s3.upload(fakeio("content"), "foo")
        assert_equal 1, @s3.client.api_requests.size

        assert_equal :put_object,   @s3.client.api_requests[0][:operation_name]
        assert_instance_of FakeIO,  @s3.client.api_requests[0][:params][:body]
        assert_equal "foo",         @s3.client.api_requests[0][:params][:key]
      end

      it "respects :prefix" do
        @s3 = s3(prefix: "prefix")
        @s3.upload(fakeio, "foo")
        assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
      end
    end

    describe "multipart upload" do
      it "is used when object has unknown size" do
        io = fakeio("a" * 6*1024*1024)
        io.instance_eval { undef size }

        @s3.upload(io, "foo")

        assert_equal [
          :create_multipart_upload,
          :upload_part,
          :upload_part,
          :complete_multipart_upload,
        ], @s3.client.api_requests.map { |r| r[:operation_name] }
      end unless RUBY_ENGINE == "jruby" # randomly fails on JRuby

      it "is used when object has nil size" do
        io = fakeio("a" * 6*1024*1024)
        io.instance_eval { def size; nil; end }

        @s3.upload(io, "foo")

        assert_equal [
          :create_multipart_upload,
          :upload_part,
          :upload_part,
          :complete_multipart_upload,
        ], @s3.client.api_requests.map { |r| r[:operation_name] }
      end unless RUBY_ENGINE == "jruby" # randomly fails on JRuby

      it "is used when object has size larger than multipart threshold" do
        @s3 = s3(multipart_threshold: { upload: 5*1024*1024 })
        @s3.upload(fakeio("a" * 6*1024*1024), "foo")

        assert_equal [
          :create_multipart_upload,
          :upload_part,
          :upload_part,
          :complete_multipart_upload,
        ], @s3.client.api_requests.map { |r| r[:operation_name] }
      end unless RUBY_ENGINE == "jruby" # randomly fails on JRuby

      it "respects :prefix" do
        @s3 = s3(multipart_threshold: { upload: 1}, prefix: "prefix")
        @s3.upload(fakeio, "foo")
        assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
      end
    end

    describe "on S3 file" do
      it "copies in a single request if small" do
        uploaded_file = @shrine.uploaded_file(id: "bar", storage: "s3", metatdata: { "size"=>10 })
        @s3.upload(uploaded_file, "foo")
        assert_equal 1, @s3.client.api_requests.size

        assert_equal :copy_object,    @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",           @s3.client.api_requests[0][:params][:key]
        assert_equal "my-bucket/bar", @s3.client.api_requests[0][:params][:copy_source]
      end

      it "copies in single request if size is unknown" do
        uploaded_file = @shrine.uploaded_file(id: "bar", storage: "s3")
        @s3.upload(uploaded_file, "foo")
        assert_equal 1, @s3.client.api_requests.size

        assert_equal :copy_object,    @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",           @s3.client.api_requests[0][:params][:key]
        assert_equal "my-bucket/bar", @s3.client.api_requests[0][:params][:copy_source]
      end

      it "copies in multipart requests if large" do
        @s3 = s3(multipart_threshold: { copy: 5*1024*1024 })
        uploaded_file = @shrine.uploaded_file(id: "bar", storage: "s3", metadata: { "size" => 6*1024*1024 })
        @s3.upload(uploaded_file, "foo", min_part_size: 5*1024*1024)
        assert_equal 4, @s3.client.api_requests.size

        assert_equal :create_multipart_upload,   @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",                      @s3.client.api_requests[0][:params][:key]

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
        uploaded_file = @shrine.uploaded_file(id: "bar", storage: "other_s3")
        @s3.upload(uploaded_file, "foo")
        assert_equal 1, @s3.client.api_requests.size

        assert_equal :copy_object,              @s3.client.api_requests[0][:operation_name]
        assert_equal "foo",                     @s3.client.api_requests[0][:params][:key]
        assert_equal "other-bucket/prefix/bar", @s3.client.api_requests[0][:params][:copy_source]
      end

      it "adds directive for replacing object metadata" do
        uploaded_file = @shrine.uploaded_file(id: "bar", storage: "s3", metadata: { "size" => 10 })
        @s3.upload(uploaded_file, "foo")
        assert_equal :copy_object, @s3.client.api_requests[0][:operation_name]
        assert_equal "REPLACE",    @s3.client.api_requests[0][:params][:metadata_directive]
      end

      it "forwards any upload options" do
        uploaded_file = @shrine.uploaded_file(id: "bar", storage: "s3", metadata: { "size" => 10 })
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert_equal :copy_object,  @s3.client.api_requests[0][:operation_name]
        assert_equal "public-read", @s3.client.api_requests[0][:params][:acl]
      end

      it "respects :prefix" do
        @s3 = s3(prefix: "prefix")
        uploaded_file = @shrine.uploaded_file(id: "bar", storage: "s3")
        @s3.upload(uploaded_file, "foo", acl: "public-read")
        assert_equal :copy_object, @s3.client.api_requests[0][:operation_name]
        assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
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

    it "respects :public option" do
      @s3 = s3(public: true)

      @s3.upload(fakeio, "foo")
      assert_equal "public-read", @s3.client.api_requests[0][:params][:acl]

      @s3.upload(fakeio, "foo", acl: "public-read-write")
      assert_equal "public-read-write", @s3.client.api_requests[1][:params][:acl]
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
      @s3.client.stub_responses(:get_object, status_code: 200, headers: { "content-length" => "7" }, body: "content")
      io = @s3.open("foo")
      assert_instance_of Down::ChunkedIO, io
      assert_equal "content", io.read
    end

    it "retrieves the content length" do
      @s3.client.stub_responses(:get_object, status_code: 200, headers: { "content-length" => "7" }, body: "content")
      io = @s3.open("foo")
      assert_equal 7, io.size
    end

    it "forwards additional options to #get_object" do
      @s3.client.stub_responses(:get_object, status_code: 200, headers: { "content-length" => "7" }, body: "content")
      io = @s3.open("foo", range: "bytes=0-100", response_content_encoding: "gzip")
      assert_equal :get_object,   @s3.client.api_requests[0][:operation_name]
      assert_equal "bytes=0-100", @s3.client.api_requests[0][:params][:range]
      assert_equal "gzip",        @s3.client.api_requests[0][:params][:response_content_encoding]
    end

    it "respects :prefix" do
      @s3 = s3(prefix: "prefix")
      @s3.client.stub_responses(:get_object, status_code: 200, headers: { "content-length" => "7" }, body: "content")
      @s3.open("foo")
      assert_equal :get_object,  @s3.client.api_requests[0][:operation_name]
      assert_equal "prefix/foo", @s3.client.api_requests[0][:params][:key]
    end

    it "accepts :rewindable option" do
      @s3.client.stub_responses(:get_object, status_code: 200, headers: { "content-length" => "7" }, body: "content")
      io = @s3.open("foo", rewindable: false)
      assert_raises(IOError) { io.rewind }
    end

    it "returns Shrine::FileNotFound when object was not found" do
      @s3.client.stub_responses(:get_object, "NoSuchKey")
      assert_raises(Shrine::FileNotFound) { @s3.open("nonexisting") }
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

  describe "#delete_prefixed" do
    it "deletes objects with specified prefix" do
      @s3.client.stub_responses(:list_objects, contents: [{ key: "delete_prefix/foo" }])
      @s3.delete_prefixed("delete_prefix")
      assert_equal :list_objects,                  @s3.client.api_requests[0][:operation_name]
      assert_equal "delete_prefix/",               @s3.client.api_requests[0][:params][:prefix]
      assert_equal :delete_objects,                @s3.client.api_requests[1][:operation_name]
      assert_equal [{ key: "delete_prefix/foo" }], @s3.client.api_requests[1][:params][:delete][:objects]
    end

    it "deletes objects with specified prefix with trailing slash" do
      @s3.client.stub_responses(:list_objects, contents: [{ key: "delete_prefix/foo" }])
      @s3.delete_prefixed("delete_prefix/")
      assert_equal :list_objects,                  @s3.client.api_requests[0][:operation_name]
      assert_equal "delete_prefix/",               @s3.client.api_requests[0][:params][:prefix]
      assert_equal :delete_objects,                @s3.client.api_requests[1][:operation_name]
      assert_equal [{ key: "delete_prefix/foo" }], @s3.client.api_requests[1][:params][:delete][:objects]
    end

    it "respects storage prefix" do
      @s3 = s3(prefix: "prefix")
      @s3.client.stub_responses(:list_objects, contents: [{ key: "prefix/delete_prefix/foo" }])
      @s3.delete_prefixed("delete_prefix")
      assert_equal :list_objects,                         @s3.client.api_requests[0][:operation_name]
      assert_equal "prefix/delete_prefix/",               @s3.client.api_requests[0][:params][:prefix]
      assert_equal :delete_objects,                       @s3.client.api_requests[1][:operation_name]
      assert_equal [{ key: "prefix/delete_prefix/foo" }], @s3.client.api_requests[1][:params][:delete][:objects]
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
end
