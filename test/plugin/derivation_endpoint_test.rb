require "test_helper"
require "shrine/plugins/derivation_endpoint"
require "rack/test_app"
require "dry-monitor"
require "tempfile"
require "stringio"
require "pathname"
require "uri"

describe Shrine::Plugins::DerivationEndpoint do
  before do
    @uploader      = uploader { plugin :derivation_endpoint, secret_key: "secret" }
    @shrine        = @uploader.class
    @uploaded_file = @uploader.upload(fakeio)
    @storage       = @uploader.storage

    @shrine.derivation(:gray) do |file, type|
      tempfile = Tempfile.new
      tempfile << ["gray", *type, "content"].join(" ")
      tempfile.rewind
      tempfile
    end
  end

  describe "UploadedFile#derivation_url" do
    it "includes derivation name" do
      derivation_url = @uploaded_file.derivation_url(:gray)
      assert_match %r{^/gray/\w+\?}, derivation_url
    end

    it "includes derivation args" do
      derivation_url = @uploaded_file.derivation_url(:gray, "dark")
      assert_match %r{^/gray/dark/\w+\?}, derivation_url
    end

    it "applies :host" do
      @shrine.plugin :derivation_endpoint, host: "https://example.com"
      derivation_url = @uploaded_file.derivation_url(:gray)
      assert_match %r{^https://example\.com/gray/\w+\?}, derivation_url

      derivation_url = @uploaded_file.derivation_url(:gray, host: "https://other.com")
      assert_match %r{^https://other\.com/gray/\w+\?}, derivation_url
    end

    it "applies :prefix" do
      @shrine.plugin :derivation_endpoint, prefix: "foo/bar"
      derivation_url = @uploaded_file.derivation_url(:gray)
      assert_match %r{^/foo/bar/gray/\w+\?}, derivation_url

      derivation_url = @uploaded_file.derivation_url(:gray, prefix: "baz")
      assert_match %r{^/baz/gray/\w+\?}, derivation_url
    end

    it "applies :host and :prefix" do
      @shrine.plugin :derivation_endpoint, prefix: "prefix", host: "https://example.com"
      derivation_url = @uploaded_file.derivation_url(:gray)
      assert_match %r{^https://example\.com/prefix/gray/\w+\?}, derivation_url
    end

    it "applies :expires_in" do
      derivation_url = @uploaded_file.derivation_url(:gray)
      refute_match %r{expires_at=}, derivation_url

      @shrine.plugin :derivation_endpoint, expires_in: 10
      derivation_url = @uploaded_file.derivation_url(:gray)
      assert_match %r{expires_at=\d+}, derivation_url
      expires_at = Integer(derivation_url[/expires_at=(\d+)/, 1])
      assert_operator Time.now + 10,       :>=, Time.at(expires_at)
      assert_operator Time.at(expires_at), :>=, Time.now

      @shrine.plugin :derivation_endpoint, expires_in: -> { 10 }
      derivation_url = @uploaded_file.derivation_url(:gray)
      assert_match %r{expires_at=\d+}, derivation_url
      expires_at = Integer(derivation_url[/expires_at=(\d+)/, 1])
      assert_operator Time.now + 10,       :>=, Time.at(expires_at)
      assert_operator Time.at(expires_at), :>=, Time.now

      derivation_url = @uploaded_file.derivation_url(:gray, expires_in: 5)
      assert_match %r{expires_at=(\d+)}, derivation_url
      expires_at = Integer(derivation_url[/expires_at=(\d+)/, 1])
      assert_operator Time.now + 5,        :>=, Time.at(expires_at)
      assert_operator Time.at(expires_at), :>=, Time.now
    end

    it "applies :version" do
      derivation_url = @uploaded_file.derivation_url(:gray)
      refute_match %r{version=}, derivation_url

      @shrine.plugin :derivation_endpoint, version: 1
      derivation_url = @uploaded_file.derivation_url(:gray)
      assert_match %r{version=1}, derivation_url

      @shrine.plugin :derivation_endpoint, version: -> { 1 }
      derivation_url = @uploaded_file.derivation_url(:gray)
      assert_match %r{version=1}, derivation_url

      derivation_url = @uploaded_file.derivation_url(:gray, version: 2)
      assert_match %r{version=2}, derivation_url
    end

    it "applies :type" do
      derivation_url = @uploaded_file.derivation_url(:gray)
      refute_match %r{type=}, derivation_url

      @shrine.plugin :derivation_endpoint, type: "text/plain"
      derivation_url = @uploaded_file.derivation_url(:gray)
      refute_match %r{type=}, derivation_url

      derivation_url = @uploaded_file.derivation_url(:gray, type: "text/csv")
      assert_match %r{type=text%2Fcsv}, derivation_url
    end

    it "applies :filename" do
      derivation_url = @uploaded_file.derivation_url(:gray)
      refute_match %r{filename=}, derivation_url

      @shrine.plugin :derivation_endpoint, filename: "custom.txt"
      derivation_url = @uploaded_file.derivation_url(:gray)
      refute_match %r{filename=}, derivation_url

      derivation_url = @uploaded_file.derivation_url(:gray, filename: "custom.txt")
      assert_match %r{filename=custom\.txt}, derivation_url
    end

    it "applies :disposition" do
      derivation_url = @uploaded_file.derivation_url(:gray)
      refute_match %r{disposition=}, derivation_url

      @shrine.plugin :derivation_endpoint, disposition: "attachment"
      derivation_url = @uploaded_file.derivation_url(:gray)
      refute_match %r{disposition=}, derivation_url

      derivation_url = @uploaded_file.derivation_url(:gray, disposition: "attachment")
      assert_match %r{disposition=attachment}, derivation_url
    end

    it "applies :metadata" do
      @uploaded_file.metadata.merge!("foo" => "bar", "baz" => "quux")

      derivation_url = @uploaded_file.derivation_url(:gray)
      uploaded_file = @shrine::UploadedFile.urlsafe_load(derivation_url[/(\w+)\?/, 1])
      assert_equal Hash.new, uploaded_file.metadata

      @shrine.plugin :derivation_endpoint, metadata: ["foo"]
      derivation_url = @uploaded_file.derivation_url(:gray)
      uploaded_file = @shrine::UploadedFile.urlsafe_load(derivation_url[/(\w+)\?/, 1])
      assert_equal Hash["foo" => "bar"], uploaded_file.metadata

      derivation_url = @uploaded_file.derivation_url(:gray, metadata: ["baz"])
      uploaded_file = @shrine::UploadedFile.urlsafe_load(derivation_url[/(\w+)\?/, 1])
      assert_equal Hash["baz" => "quux"], uploaded_file.metadata
    end

    it "escapes path and query params" do
      derivation_url = @uploaded_file.derivation_url(:gray, "foo bar", filename: "foo bar")
      assert_match /gray\/foo%20bar/,   URI(derivation_url).path
      assert_match /filename=foo\+bar/, URI(derivation_url).query
    end

    it "generates signature from derivation name, args, params, and secret key" do
      derivation_urls = [
        @uploaded_file.derivation_url(:foo),
        @uploaded_file.derivation_url(:bar),
        @uploaded_file.derivation_url(:foo, "foo"),
        @uploaded_file.derivation_url(:foo, "bar"),
        @uploaded_file.derivation_url(:foo, expires_in: 10),
        @uploaded_file.derivation_url(:foo, expires_in: 20),
        @uploaded_file.derivation(:foo, secret_key: "other_secret").url,
      ]

      signatures = derivation_urls.map { |url| url[/signature=(\w+)/, 1] }

      assert_equal signatures, signatures.uniq
    end

    it "doesn't change the existing signature" do
      @uploaded_file = @uploader.upload(fakeio, location: "consistent-location")
      derivation_url = @uploaded_file.derivation_url(:foo)
      signature = derivation_url[/signature=(\w+)/, 1]
      assert_equal "9599ad1f343bd125cbf5bda3eb91c89165f00c8127b03ffc168f2a914a4267e2", signature
    end

    it "doesn't require the derivation to exist" do
      derivation_url = @uploaded_file.derivation_url(:other)
      assert_match %r{/other/\w+\?}, derivation_url
    end
  end

  describe "Shrine.derivation_endpoint" do
    def app(*args)
      Rack::TestApp.wrap(Rack::Lint.new(endpoint(*args)))
    end

    def endpoint(*args)
      @shrine.derivation_endpoint(*args)
    end

    it "generates correct derivation response" do
      derivation_url = @uploaded_file.derivation_url(:gray, "dark")
      response = app.get(derivation_url)
      assert_equal 200,                 response.status
      assert_equal "gray dark content", response.body_binary
      assert_equal "17",                response.headers["Content-Length"]
    end

    it "handles Range requests" do
      derivation_url = @uploaded_file.derivation_url(:gray)
      response = app.get(derivation_url, headers: { "Range" => "bytes=0-3" })
      assert_equal 206,            response.status
      assert_equal "gray",         response.body_binary
      assert_equal "4",            response.headers["Content-Length"]
      assert_equal "bytes 0-3/12", response.headers["Content-Range"]
    end

    it "applies plugin options" do
      @shrine.plugin :derivation_endpoint, disposition: "attachment"
      derivation_url = @uploaded_file.derivation_url(:gray)
      response = app.get(derivation_url)
      assert_equal 200,          response.status
      assert_match "attachment", response.headers["Content-Disposition"]
    end

    it "applies app options" do
      @shrine.plugin :derivation_endpoint, disposition: "inline"
      derivation_url = @uploaded_file.derivation_url(:gray)
      response = app(disposition: "attachment").get(derivation_url)
      assert_equal 200,          response.status
      assert_match "attachment", response.headers["Content-Disposition"]
    end

    it "applies 'type' param" do
      @shrine.plugin :derivation_endpoint, type: "text/plain"
      derivation_url = @uploaded_file.derivation_url(:gray, type: "text/csv")
      response = app(type: "text/plain").get(derivation_url)
      assert_equal 200,        response.status
      assert_equal "text/csv", response.headers["Content-Type"]
    end

    it "applies 'disposition' param" do
      @shrine.plugin :derivation_endpoint, disposition: "inline"
      derivation_url = @uploaded_file.derivation_url(:gray, disposition: "attachment")
      response = app(disposition: "inline").get(derivation_url)
      assert_equal 200,          response.status
      assert_match "attachment", response.headers["Content-Disposition"]
    end

    it "applies 'filename' param" do
      @shrine.plugin :derivation_endpoint, filename: "default"
      derivation_url = @uploaded_file.derivation_url(:gray, filename: "custom")
      response = app(filename: "default").get(derivation_url)
      assert_equal 200,                   response.status
      assert_match "filename=\"custom\"", response.headers["Content-Disposition"]
    end

    it "returns Cache-Control header on 2xx response" do
      derivation_url = @uploaded_file.derivation_url(:gray)
      response = app.get(derivation_url)
      assert_equal 200,                        response.status
      assert_equal "public, max-age=31536000", response.headers["Cache-Control"]

      derivation_url = @uploaded_file.derivation_url(:gray)
      response = app.get(derivation_url, headers: { "Range" => "bytes=0-3" })
      assert_equal 206,                        response.status
      assert_equal "public, max-age=31536000", response.headers["Cache-Control"]

      derivation_url = @uploaded_file.derivation_url(:gray)
      response = app(upload: true, upload_redirect: true).get(derivation_url)
      assert_equal 302, response.status
      refute response.headers.key?("Cache-Control")
    end

    it "applies :cache_control" do
      @shrine.plugin :derivation_endpoint, cache_control: "public, max-age=10"
      derivation_url = @uploaded_file.derivation_url(:gray)
      response = app.get(derivation_url)
      assert_equal "public, max-age=10", response.headers["Cache-Control"]

      response = app(cache_control: "public, max-age=20").get(derivation_url)
      assert_equal "public, max-age=20", response.headers["Cache-Control"]

      response = app(cache_control: -> { "public, max-age=20" }).get(derivation_url)
      assert_equal "public, max-age=20", response.headers["Cache-Control"]

      derivation_url = @uploaded_file.derivation_url(:gray, expires_in: 100)
      response = app.get(derivation_url)
      assert_equal "public, max-age=10", response.headers["Cache-Control"]
    end

    it "returns 404 on unknown derivation" do
      derivation_url = @uploaded_file.derivation_url(:nonexistent)
      response = app.get(derivation_url)
      assert_equal 404,                              response.status
      assert_match "Unknown derivation",             response.body_binary
      assert_equal response.body_binary.length.to_s, response.headers["Content-Length"]
    end

    it "returns 404 when error from :download_errors is raised" do
      @shrine.plugin :derivation_endpoint, download_errors: [KeyError]
      @uploaded_file.delete
      derivation_url = @uploaded_file.derivation_url(:gray)
      response = app.get(derivation_url)
      assert_equal 404,                              response.status
      assert_match "Source file not found",          response.body_binary
      assert_equal response.body_binary.length.to_s, response.headers["Content-Length"]
    end

    it "propagates download errors when :download_errors is not specified" do
      @shrine.plugin :derivation_endpoint
      derivation_url = @uploaded_file.derivation_url(:gray)
      @uploaded_file.delete
      assert_raises(KeyError) do
        app.get(derivation_url)
      end
    end

    it "successfully handles expiring links that have not yet expired" do
      derivation_url = @uploaded_file.derivation_url(:gray, expires_in: 100)
      response = app.get(derivation_url)
      assert_equal 200,  response.status
      assert_equal "12", response.headers["Content-Length"]

      # caching duration is limited by the expiration date
      max_age = Integer(response.headers["Cache-Control"][/max-age=(\d+)/, 1])
      assert_operator max_age, :<=, 100
      assert_operator 0,       :<, max_age
    end

    it "returns 403 when link has expired" do
      derivation_url = @uploaded_file.derivation_url(:gray, expires_in: -1)
      @shrine.derivation(:gray) { fail "this should not be called" }
      response = app.get(derivation_url)
      assert_equal 403,                              response.status
      assert_match "Request has expired",            response.body_binary
      assert_equal response.body_binary.length.to_s, response.headers["Content-Length"]
      refute response.headers.key?("Cache-Control")
    end

    it "returns 403 on invalid signature" do
      derivation_url = @uploaded_file.derivation_url(:gray).sub(/\w+$/, "foo")
      @shrine.derivation(:gray) { fail "this should not be called" }
      response = app.get(derivation_url)
      assert_equal 403,                              response.status
      assert_match "signature does not match",       response.body_binary
      assert_equal response.body_binary.length.to_s, response.headers["Content-Length"]
      refute response.headers.key?("Cache-Control")
    end

    it "returns 403 on missing signature" do
      derivation_url = @uploaded_file.derivation_url(:gray).sub(/signature=\w+$/, "")
      @shrine.derivation(:gray) { fail "this should not be called" }
      response = app.get(derivation_url)
      assert_equal 403,                              response.status
      assert_match "Missing \"signature\" param",    response.body_binary
      assert_equal response.body_binary.length.to_s, response.headers["Content-Length"]
      refute response.headers.key?("Cache-Control")
    end

    it "includes request params when calculating signature" do
      derivation_url = @uploaded_file.derivation_url(:gray) + "&foo=bar"
      response = app.get(derivation_url)
      assert_equal 403,                              response.status
      assert_match "signature does not match",       response.body_binary
      assert_equal response.body_binary.length.to_s, response.headers["Content-Length"]
    end

    it "accepts HEAD requests" do
      derivation_url = @uploaded_file.derivation_url(:gray)
      response = app.head(derivation_url)
      assert_equal 200,  response.status
      assert_equal "12", response.headers["Content-Length"]
    end

    it "returns 405 on invalid request method" do
      derivation_url = @uploaded_file.derivation_url(:gray)
      response = app.post(derivation_url)
      assert_equal 405,                              response.status
      assert_equal "Method not allowed",             response.body_binary
      assert_equal response.body_binary.length.to_s, response.headers["Content-Length"]
    end

    it "defines #inspect and #to_s" do
      assert_equal "#<#{@shrine}::DerivationEndpoint>", endpoint.inspect
      assert_equal "#<#{@shrine}::DerivationEndpoint>", endpoint.to_s
    end
  end

  describe "Shrine.derivation_response" do
    it "works in the main app" do
      @shrine.plugin :derivation_endpoint, prefix: "derivations"

      derivation_url = @uploaded_file.derivation_url(:gray)

      env = {
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME"    => "",
        "PATH_INFO"      => URI(derivation_url).path,
        "QUERY_STRING"   => URI(derivation_url).query,
        "rack.input"     => StringIO.new,
      }

      status, headers, body = @shrine.derivation_response(env)

      assert_equal 200,            status
      assert_equal "12",           headers["Content-Length"]
      assert_equal "gray content", body.enum_for(:each).to_a.join

      assert_equal "",                       env["SCRIPT_NAME"]
      assert_equal URI(derivation_url).path, env["PATH_INFO"]
    end

    it "works in a mounted app" do
      @shrine.plugin :derivation_endpoint, prefix: "derivations"

      derivation_url = @uploaded_file.derivation_url(:gray)

      env = {
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME"    => "/foo",
        "PATH_INFO"      => URI(derivation_url).path,
        "QUERY_STRING"   => URI(derivation_url).query,
        "rack.input"     => StringIO.new,
      }

      status, headers, body = @shrine.derivation_response(env)

      assert_equal 200,    status
      assert_equal "/foo", env["SCRIPT_NAME"]
    end

    it "accepts additional options" do
      @shrine.plugin :derivation_endpoint, prefix: "derivations"

      derivation_url = @uploaded_file.derivation_url(:gray)

      env = {
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME"    => "",
        "PATH_INFO"      => URI(derivation_url).path,
        "QUERY_STRING"   => URI(derivation_url).query,
        "rack.input"     => StringIO.new,
      }

      status, headers, body = @shrine.derivation_response(env, type: "text/plain")

      assert_equal 200,          status
      assert_equal "text/plain", headers["Content-Type"]
    end

    it "fails when request path doesn't start with prefix" do
      @shrine.plugin :derivation_endpoint, prefix: "derivations"

      derivation_url = @uploaded_file.derivation_url(:gray, prefix: "other")

      env = {
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME"    => "",
        "PATH_INFO"      => URI(derivation_url).path,
        "QUERY_STRING"   => URI(derivation_url).query,
        "rack.input"     => StringIO.new,
      }

      assert_raises(Shrine::Error) do
        @shrine.derivation_response(env)
      end
    end
  end

  describe "UploadedFile#derivation_response" do
    describe "by default" do
      it "returns derivation response" do
        response = @uploaded_file.derivation_response(:gray, env: {})

        assert_equal 200,            response[0]
        assert_equal "12",           response[1]["Content-Length"]
        assert_equal "gray content", response[2].enum_for(:each).to_a.join
      end

      it "returns Content-Disposition" do
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal ContentDisposition.inline("gray-#{@uploaded_file.id}"), response[1]["Content-Disposition"]

        response = @uploaded_file.derivation_response(:gray, "dark", env: {})
        assert_equal ContentDisposition.inline("gray-dark-#{@uploaded_file.id}"), response[1]["Content-Disposition"]

        @shrine.derivation(:gray) { |file| Tempfile.new(["derivation", ".txt"]) }
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal ContentDisposition.inline("gray-#{@uploaded_file.id}.txt"), response[1]["Content-Disposition"]
      end

      it "returns Content-Type" do
        @shrine.derivation(:gray) { |file| Tempfile.new(["derivation", ".jpg"]) }
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal "image/jpeg", response[1]["Content-Type"]

        @shrine.derivation(:gray) { |file| Tempfile.new(["derivation"]) }
        response = @uploaded_file.derivation_response(:gray, env: {})
        refute response[1].key?("Content-Type")
      end

      it "applies :type" do
        @shrine.derivation(:gray) { |file| Tempfile.new(["derivation", ".jpg"]) }

        @shrine.plugin :derivation_endpoint, type: "text/plain"
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal "text/plain", response[1]["Content-Type"]

        @shrine.plugin :derivation_endpoint, type: -> { "text/plain" }
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal "text/plain", response[1]["Content-Type"]

        response = @uploaded_file.derivation_response(:gray, env: {}, type: "text/csv")
        assert_equal "text/csv", response[1]["Content-Type"]

        response = @uploaded_file.derivation_response(:gray, env: {}, type: -> { "text/csv" })
        assert_equal "text/csv", response[1]["Content-Type"]
      end

      it "applies :disposition" do
        @shrine.plugin :derivation_endpoint, disposition: "attachment"
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_match "attachment; ", response[1]["Content-Disposition"]

        @shrine.plugin :derivation_endpoint, disposition: -> { "attachment" }
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_match "attachment; ", response[1]["Content-Disposition"]

        response = @uploaded_file.derivation_response(:gray, env: {}, disposition: "inline")
        assert_match "inline; ", response[1]["Content-Disposition"]

        response = @uploaded_file.derivation_response(:gray, env: {}, disposition: -> { "inline" })
        assert_match "inline; ", response[1]["Content-Disposition"]
      end

      it "applies :filename" do
        @shrine.derivation(:gray) { |file| Tempfile.new(["derivation", ".txt"]) }

        @shrine.plugin :derivation_endpoint, filename: "one"
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_match "inline; filename=\"one.txt\"", response[1]["Content-Disposition"]

        @shrine.plugin :derivation_endpoint, filename: -> { "one" }
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_match "inline; filename=\"one.txt\"", response[1]["Content-Disposition"]

        response = @uploaded_file.derivation_response(:gray, env: {}, filename: "two.csv")
        assert_match "inline; filename=\"two.csv\"", response[1]["Content-Disposition"]

        response = @uploaded_file.derivation_response(:gray, env: {}, filename: -> { "two.csv" })
        assert_match "inline; filename=\"two.csv\"", response[1]["Content-Disposition"]
      end

      it "handles Range requests" do
        response = @uploaded_file.derivation_response(:gray, env: { "HTTP_RANGE" => "bytes=0-3" })
        assert_equal 206,            response[0]
        assert_equal "bytes 0-3/12", response[1]["Content-Range"]
        assert_equal "bytes",        response[1]["Accept-Ranges"]
        assert_equal "gray",         response[2].enum_for(:each).to_a.join

        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal 200,     response[0]
        assert_equal "bytes", response[1]["Accept-Ranges"]
        refute response[1].key?("Content-Range")
      end

      it "closes and deletes derivation result" do
        tempfile = Tempfile.new
        tempfile.write "file content"
        tempfile.flush

        file = File.open(tempfile.path)

        derivation = @uploaded_file.derivation(:gray)
        derivation.expects(:generate).returns(file)

        response = derivation.response({})
        assert_equal "file content", response[2].enum_for(:each).to_a.join

        response[2].close
        assert file.closed?
        refute File.exist?(file.path)
      end
    end

    describe "with :upload" do
      before do
        @shrine.plugin :derivation_endpoint, upload: true
      end

      it "returns local file response the first time" do
        response = @uploaded_file.derivation_response(:gray, env: {})

        assert_equal 200,            response[0]
        assert_equal "12",           response[1]["Content-Length"]
        assert_equal "gray content", response[2].enum_for(:each).to_a.join

        refute_instance_of Shrine::Plugins::RackResponse::FileBody, response[2]
      end

      it "returns uploaded file response the second time" do
        @uploaded_file.derivation_response(:gray, env: {})
        @shrine.derivation(:gray) { fail "this should not be called anymore" }

        response = @uploaded_file.derivation_response(:gray, env: {})

        assert_equal 200,            response[0]
        assert_equal "12",           response[1]["Content-Length"]
        assert_equal "gray content", response[2].enum_for(:each).to_a.join
      end

      it "applies :type" do
        @uploaded_file.derivation_response(:gray, env: {})

        @shrine.plugin :derivation_endpoint, type: "text/plain"
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal "text/plain", response[1]["Content-Type"]

        @shrine.plugin :derivation_endpoint, type: -> { "text/plain" }
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal "text/plain", response[1]["Content-Type"]

        response = @uploaded_file.derivation_response(:gray, env: {}, type: "text/csv")
        assert_equal "text/csv", response[1]["Content-Type"]

        response = @uploaded_file.derivation_response(:gray, env: {}, type: -> { "text/csv" })
        assert_equal "text/csv", response[1]["Content-Type"]
      end

      it "applies :disposition" do
        @uploaded_file.derivation_response(:gray, env: {})

        @shrine.plugin :derivation_endpoint, disposition: "attachment"
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_match "attachment; ", response[1]["Content-Disposition"]

        @shrine.plugin :derivation_endpoint, disposition: -> { "attachment" }
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_match "attachment; ", response[1]["Content-Disposition"]

        response = @uploaded_file.derivation_response(:gray, env: {}, disposition: "inline")
        assert_match "inline; ", response[1]["Content-Disposition"]

        response = @uploaded_file.derivation_response(:gray, env: {}, disposition: -> { "inline" })
        assert_match "inline; ", response[1]["Content-Disposition"]
      end

      it "applies :filename" do
        @uploaded_file.derivation_response(:gray, env: {})

        @shrine.plugin :derivation_endpoint, filename: "one"
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_match "inline; filename=\"one\"", response[1]["Content-Disposition"]

        @shrine.plugin :derivation_endpoint, filename: -> { "one" }
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_match "inline; filename=\"one\"", response[1]["Content-Disposition"]

        response = @uploaded_file.derivation_response(:gray, env: {}, filename: "two")
        assert_match "inline; filename=\"two\"", response[1]["Content-Disposition"]

        response = @uploaded_file.derivation_response(:gray, env: {}, filename: -> { "two" })
        assert_match "inline; filename=\"two\"", response[1]["Content-Disposition"]
      end

      it "handles Range requests" do
        @uploaded_file.derivation_response(:gray, env: {})
        response = @uploaded_file.derivation_response(:gray, env: { "HTTP_RANGE" => "bytes=0-3" })
        assert_equal 206,            response[0]
        assert_equal "bytes 0-3/12", response[1]["Content-Range"]
        assert_equal "bytes",        response[1]["Accept-Ranges"]
        assert_equal "gray",         response[2].enum_for(:each).to_a.join
      end

      it "returns ETag" do
        @uploaded_file.derivation_response(:gray, env: {})
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_instance_of String,    response[1]["ETag"]
        assert_match /^W\/"\w{32}"$/, response[1]["ETag"]
      end

      it "applies :upload_open_options" do
        @shrine.plugin :derivation_endpoint, upload_open_options: { foo: "bar" }
        @uploaded_file.derivation_response(:gray, env: {})

        @storage.expects(:open).with("#{@uploaded_file.id}/gray", foo: "bar").returns(StringIO.new)
        @uploaded_file.derivation_response(:gray, env: {})
      end

      it "applies :upload_redirect" do
        @shrine.plugin :derivation_endpoint, upload_redirect: true
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal 302,                                       response[0]
        assert_equal @storage.url("#{@uploaded_file.id}/gray"), response[1]["Location"]
        assert_equal "",                                        response[2].enum_for(:each).to_a.join

        # when derivative is already uploaded
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal 302,                                       response[0]
        assert_equal @storage.url("#{@uploaded_file.id}/gray"), response[1]["Location"]
        assert_equal "",                                        response[2].enum_for(:each).to_a.join
      end

      it "closes and deletes derivation result on :upload_redirect" do
        @shrine.plugin :derivation_endpoint, upload_redirect: true
        tempfile = Tempfile.new
        file     = File.open(tempfile.path)

        derivation = @uploaded_file.derivation(:gray)
        derivation.expects(:generate).returns(file)

        derivation.response({})

        assert file.closed?
        refute File.exist?(file.path)
      end

      it "applies :upload_redirect_url_options" do
        @shrine.plugin :derivation_endpoint, upload_redirect: true, upload_redirect_url_options: { foo: "foo" }
        @storage.expects(:url).with("#{@uploaded_file.id}/gray", foo: "foo").returns("foo")
        response = @uploaded_file.derivation_response(:gray, env: {})
        assert_equal 302,   response[0]
        assert_equal "foo", response[1]["Location"]

        @storage.expects(:url).with("#{@uploaded_file.id}/gray", bar: "bar").returns("bar")
        response = @uploaded_file.derivation_response(:gray, env: {}, upload_redirect_url_options: { bar: "bar" })
        assert_equal 302,   response[0]
        assert_equal "bar", response[1]["Location"]
      end
    end
  end

  describe "Derivation" do
    describe "#processed" do
      describe "by default" do
        it "returns derivation result" do
          tempfile = @uploaded_file.derivation(:gray).processed
          assert_instance_of Tempfile, tempfile
          assert_equal "gray content", tempfile.read
        end
      end

      describe "with :upload" do
        before do
          @shrine.plugin :derivation_endpoint, upload: true
        end

        it "uploads derivation result" do
          uploaded_file = @uploaded_file.derivation(:gray).processed
          assert_instance_of @shrine::UploadedFile, uploaded_file
          assert_equal "gray content", uploaded_file.read
        end

        it "deletes derivation result after uploading" do
          tempfile = Tempfile.new
          @shrine.derivation(:gray) { File.open(tempfile.path) }
          @uploaded_file.derivation(:gray).processed
          refute File.exist?(tempfile.path)
        end

        it "retrieves already uploaded derivation" do
          @uploaded_file.derivation(:gray).upload
          @shrine.derivation(:gray) { fail "this should not be called" }
          @storage.expects(:upload).never
          uploaded_file = @uploaded_file.derivation(:gray).processed
          assert_instance_of @shrine::UploadedFile, uploaded_file
          assert_equal "gray content", uploaded_file.read
        end
      end
    end

    describe "#generate" do
      it "returns the derivative" do
        tempfile = @uploaded_file.derivation(:gray).generate
        assert_instance_of Tempfile, tempfile
        assert_equal "gray content", tempfile.read
      end

      it "allows passing already downloaded file" do
        tempfile = Tempfile.new
        minitest = self

        @shrine.derivation(:gray) do |file|
          minitest.assert_equal tempfile, file

          Tempfile.new
        end

        @uploaded_file.expects(:download).never

        @uploaded_file.derivation(:gray).generate(tempfile)
      end

      it "passes downloaded file and derivation arguments for processing" do
        minitest = self

        @shrine.derivation(:gray) do |file, *args|
          minitest.assert_instance_of Tempfile, file
          minitest.assert_equal "original", file.read
          minitest.assert_equal ["dark", "sepia"], args

          Tempfile.new
        end

        @uploaded_file = @uploader.upload(fakeio("original"))
        @uploaded_file.derivation(:gray, "dark", "sepia").generate
      end

      it "applies :download_options" do
        @shrine.plugin :derivation_endpoint, download_options: { foo: "foo" }
        @uploaded_file.expects(:download).with(foo: "foo").returns(Tempfile.new)
        @uploaded_file.derivation(:gray).generate

        @uploaded_file.expects(:download).with(bar: "bar").returns(Tempfile.new)
        @uploaded_file.derivation(:gray, download_options: { bar: "bar" }).generate
      end

      it "applies :include_uploaded_file" do
        minitest = self

        @shrine.derivation(:gray) do |file, uploaded_file, *args|
          minitest.assert_instance_of Tempfile, file
          minitest.assert_instance_of self.class::UploadedFile, uploaded_file
          minitest.assert_equal ["dark"], args

          Tempfile.new
        end

        @shrine.plugin :derivation_endpoint, include_uploaded_file: true
        @uploaded_file.derivation(:gray, "dark").generate
      end

      it "applies :download" do
        minitest = self

        @shrine.derivation(:gray) do |uploaded_file, *args|
          minitest.assert_instance_of self.class::UploadedFile, uploaded_file
          minitest.refute uploaded_file.opened?
          minitest.assert_equal ["dark"], args

          Tempfile.new
        end

        @shrine.plugin :derivation_endpoint, download: false
        @storage.expects(:open).never
        @uploaded_file.derivation(:gray, "dark").generate
      end

      it "raises SourceNotFound on error from :download_errors raised on downloading" do
        @shrine.plugin :derivation_endpoint, download_errors: [KeyError]
        @uploaded_file.delete
        assert_raises(Shrine::Derivation::SourceNotFound) do
          @uploaded_file.derivation(:gray).generate
        end
      end

      it "propagates errors from :download_errors raised in derivation block" do
        @shrine.plugin :derivation_endpoint, download_errors: [KeyError]
        @shrine.derivation(:gray) { raise KeyError }
        assert_raises(KeyError) do
          @uploaded_file.derivation(:gray).generate
        end
      end

      it "rewinds, flushes, and binmodes Tempfiles" do
        tempfile = Tempfile.new
        tempfile << "gray content"
        @shrine.derivation(:gray) { tempfile }
        result = @uploaded_file.derivation(:gray).generate
        assert_equal tempfile, result
        refute result.closed?
        assert result.binmode?
        assert_equal "gray content", result.read
        assert_equal "gray content", File.read(result.path)
      end

      it "rewinds, flushes, and binmodes Files" do
        tempfile = Tempfile.new
        file = File.open(tempfile.path, "w")
        file << "gray content"
        @shrine.derivation(:gray) { file }
        result = @uploaded_file.derivation(:gray).generate
        assert_instance_of File, result
        refute result.closed?
        assert result.binmode?
        assert_equal "gray content", result.read
        assert_equal "gray content", File.read(result.path)
      end

      it "accepts String paths" do
        tempfile = Tempfile.new
        tempfile << "gray content"
        tempfile.open
        @shrine.derivation(:gray) { tempfile.path }
        result = @uploaded_file.derivation(:gray).generate
        assert_instance_of File, result
        refute result.closed?
        assert result.binmode?
        assert_equal "gray content", result.read
        assert_equal "gray content", File.read(result.path)
      end

      it "accepts Pathname paths" do
        tempfile = Tempfile.new
        tempfile << "gray content"
        tempfile.open
        @shrine.derivation(:gray) { Pathname(tempfile.path) }
        result = @uploaded_file.derivation(:gray).generate
        assert_instance_of File, result
        refute result.closed?
        assert result.binmode?
        assert_equal "gray content", result.read
        assert_equal "gray content", File.read(result.path)
      end

      it "fails when derivative is of unsupported type" do
        @shrine.derivation(:gray) { |file| StringIO.new }
        assert_raises(Shrine::Error) do
          @uploaded_file.derivation(:gray, "dark").generate
        end
      end

      it "raises NotFound when derivation was not found" do
        derivation = @uploaded_file.derivation(:unknown)
        assert_raises(Shrine::Derivation::NotFound) do
          derivation.generate
        end
      end

      describe "with instrumentation" do
        before do
          @shrine.plugin :instrumentation, notifications: Dry::Monitor::Notifications.new(:test)
        end

        it "logs derivation" do
          @shrine.plugin :derivation_endpoint

          assert_logged /^Derivation \(\d+ms\) – \{.+\}$/ do
            @uploaded_file.derivation(:gray).generate
          end
        end

        it "sends a derivation event" do
          @shrine.plugin :derivation_endpoint

          @shrine.subscribe(:derivation) { |event| @event = event }
          @uploaded_file.derivation(:gray, "dark").generate

          refute_nil @event
          assert_equal :derivation,              @event.name
          assert_equal :gray,                    @event[:name]
          assert_equal ["dark"],                 @event[:args]
          assert_instance_of Shrine::Derivation, @event[:derivation]
          assert_equal @shrine,                  @event[:uploader]
          assert_instance_of Integer,            @event.duration
        end

        it "allows swapping log subscriber" do
          @shrine.plugin :derivation_endpoint, log_subscriber: -> (event) { @event = event }

          refute_logged /^Signature/ do
            @uploaded_file.derivation(:gray).generate
          end

          refute_nil @event
        end

        it "allows disabling log subscriber" do
          @shrine.plugin :derivation_endpoint, log_subscriber: nil

          refute_logged /^Signature/ do
            @uploaded_file.derivation(:gray).generate
          end
        end
      end
    end

    describe "#upload" do
      it "uploads derivation result and returns uploaded file" do
        uploaded_file = @uploaded_file.derivation(:gray).upload
        assert_instance_of @shrine::UploadedFile, uploaded_file
        assert_equal "gray content", uploaded_file.read
      end

      it "deletes the generated derivation result" do
        tempfile = Tempfile.new
        tempfile << "content"
        tempfile.open

        file = File.open(tempfile.path)
        derivation = @uploaded_file.derivation(:gray)
        derivation.expects(:generate).returns(file)

        derivation.upload

        assert file.closed?
        refute File.exist?(file.path)
      end

      it "allows uploading already generated derivative" do
        @shrine.derivation(:gray) { fail "this should not be called" }
        file = Tempfile.new
        file << "content"
        file.open
        uploaded_file = @uploaded_file.derivation(:gray).upload(file)
        assert_equal "content", uploaded_file.read
        refute file.closed?
        assert File.exist?(file.path)
        assert_equal 0, file.pos
      end

      it "applies :upload_options" do
        @shrine.plugin :derivation_endpoint, upload_options: { foo: "foo" }
        @storage.expects(:upload).with { |*, **options| options[:foo] == "foo" }
        @uploaded_file.derivation(:gray).upload

        @storage.expects(:upload).with { |*, **options| options[:bar] == "bar" }
        @uploaded_file.derivation(:gray, upload_options: { bar: "bar" }).upload
      end

      it "applies :upload_location" do
        @shrine.plugin :derivation_endpoint, upload_location: -> { "foo" }
        uploaded_file = @uploaded_file.derivation(:gray).upload
        assert_equal "foo",          uploaded_file.id
        assert_equal "gray content", uploaded_file.read

        uploaded_file = @uploaded_file.derivation(:gray, upload_location: "bar").upload
        assert_equal "bar",          uploaded_file.id
        assert_equal "gray content", uploaded_file.read
      end

      it "appends :version to :upload_location" do
        @shrine.plugin :derivation_endpoint, version: 1
        uploaded_file = @uploaded_file.derivation(:gray).upload
        assert_equal "#{@uploaded_file.id}/gray-1", uploaded_file.id
        assert_equal "gray content",                uploaded_file.read

        @shrine.plugin :derivation_endpoint, version: 1, upload_location: -> { "foo.txt" }
        uploaded_file = @uploaded_file.derivation(:gray).upload
        assert_equal "foo-1.txt",    uploaded_file.id
        assert_equal "gray content", uploaded_file.read
      end

      it "applies :upload_storage" do
        @shrine.plugin :derivation_endpoint, upload_storage: :cache
        uploaded_file = @uploaded_file.derivation(:gray).upload
        assert_equal "cache",        uploaded_file.storage_key
        assert_equal "gray content", uploaded_file.read

        uploaded_file = @uploaded_file.derivation(:gray, upload_storage: :store).upload
        assert_equal "store",        uploaded_file.storage_key
        assert_equal "gray content", uploaded_file.read
      end

      it "excludes original extension from default upload location" do
        @uploaded_file = @uploader.upload(fakeio, location: "foo.jpg")
        uploaded_file = @uploaded_file.derivation(:gray, "dark").upload
        assert_equal "foo/gray-dark", uploaded_file.id
        assert_equal "gray dark content",  uploaded_file.read
      end

      it "disables delete_raw plugin" do
        @shrine.plugin :delete_raw
        file = Tempfile.new
        @uploaded_file.derivation(:gray).upload(file)
        assert File.exist?(file.path)
      end

      it "disables moving plugin" do
        @shrine.plugin :moving
        @uploader.storage.instance_eval { def movable?(*); true; end }
        file = Tempfile.new
        @uploaded_file.derivation(:gray).upload(file)
        assert @uploaded_file.exists?
        assert File.exist?(file.path)
      end
    end

    describe "#retrieve" do
      it "returns uploaded file if found" do
        assert_nil @uploaded_file.derivation(:gray).retrieve

        @uploaded_file.derivation(:gray).upload
        uploaded_file = @uploaded_file.derivation(:gray).retrieve
        assert_instance_of @shrine::UploadedFile, uploaded_file
        assert_equal "gray content", uploaded_file.read
      end

      it "applies :upload_location" do
        @shrine.plugin :derivation_endpoint, upload_location: -> { "foo" }
        @uploaded_file.derivation(:gray).upload
        uploaded_file = @uploaded_file.derivation(:gray).retrieve
        assert_equal "foo",          uploaded_file.id
        assert_equal "gray content", uploaded_file.read

        @uploaded_file.derivation(:gray, upload_location: "bar").upload
        uploaded_file = @uploaded_file.derivation(:gray, upload_location: "bar").retrieve
        assert_equal "bar",          uploaded_file.id
        assert_equal "gray content", uploaded_file.read
      end

      it "appends :version to :upload_location" do
        @shrine.plugin :derivation_endpoint, version: 1
        @uploaded_file.derivation(:gray).upload
        uploaded_file = @uploaded_file.derivation(:gray).retrieve
        assert_equal "#{@uploaded_file.id}/gray-1", uploaded_file.id
        assert_equal "gray content",                uploaded_file.read

        @shrine.plugin :derivation_endpoint, version: 1, upload_location: -> { "foo.txt" }
        @uploaded_file.derivation(:gray).upload
        uploaded_file = @uploaded_file.derivation(:gray).retrieve
        assert_equal "foo-1.txt",    uploaded_file.id
        assert_equal "gray content", uploaded_file.read
      end

      it "applies :upload_storage" do
        @shrine.plugin :derivation_endpoint, upload_storage: :cache
        @uploaded_file.derivation(:gray).upload
        uploaded_file = @uploaded_file.derivation(:gray).retrieve
        assert_equal "cache",        uploaded_file.storage_key
        assert_equal "gray content", uploaded_file.read

        @uploaded_file.derivation(:gray, upload_storage: :store).upload
        uploaded_file = @uploaded_file.derivation(:gray, upload_storage: :store).retrieve
        assert_equal "store",        uploaded_file.storage_key
        assert_equal "gray content", uploaded_file.read
      end

      it "excludes original extension from default upload location" do
        @uploaded_file = @uploader.upload(fakeio, location: "foo.jpg")
        @uploaded_file.derivation(:gray, "dark").upload
        uploaded_file = @uploaded_file.derivation(:gray, "dark").retrieve
        assert_equal "foo/gray-dark", uploaded_file.id
        assert_equal "gray dark content",  uploaded_file.read
      end
    end

    describe "#delete" do
      it "deletes the derivative from the storage" do
        uploaded_file = @uploaded_file.derivation(:gray).upload
        @uploaded_file.derivation(:gray).delete
        refute uploaded_file.exists?
      end

      it "applies :upload_location" do
        @shrine.plugin :derivation_endpoint, upload_location: -> { "foo" }
        uploaded_file = @uploaded_file.derivation(:gray).upload
        @uploaded_file.derivation(:gray).delete
        assert_equal "foo", uploaded_file.id
        refute uploaded_file.exists?

        uploaded_file = @uploaded_file.derivation(:gray, upload_location: "bar").upload
        @uploaded_file.derivation(:gray, upload_location: "bar").delete
        assert_equal "bar", uploaded_file.id
        refute uploaded_file.exists?
      end

      it "applies :upload_storage" do
        @shrine.plugin :derivation_endpoint, upload_storage: :cache
        uploaded_file = @uploaded_file.derivation(:gray).upload
        @uploaded_file.derivation(:gray).delete
        assert_equal "cache", uploaded_file.storage_key
        refute uploaded_file.exists?

        uploaded_file = @uploaded_file.derivation(:gray, upload_storage: :store).upload
        @uploaded_file.derivation(:gray, upload_storage: :store).delete
        assert_equal "store", uploaded_file.storage_key
        refute uploaded_file.exists?
      end
    end

    describe "#option" do
      it "returns value of the specified plugin option" do
        upload_location = @uploaded_file.derivation(:gray).option(:upload_location)
        assert_equal "#{@uploaded_file.id}/gray", upload_location

        @shrine.plugin :derivation_endpoint, version: 1
        upload_location = @uploaded_file.derivation(:gray).option(:upload_location)
        assert_equal "#{@uploaded_file.id}/gray-1", upload_location

        upload_location = @uploaded_file.derivation(:gray, upload_location: "foo").option(:upload_location)
        assert_equal "foo-1", upload_location
      end

      it "returns adhoc options before plugin options" do
        @shrine.plugin :derivation_endpoint, upload: true
        derivation = @uploaded_file.derivation(:gray)
        assert_equal true, derivation.option(:upload)
        derivation = @uploaded_file.derivation(:gray, upload: false)
        assert_equal false, derivation.option(:upload)
        derivation = @uploaded_file.derivation(:gray, upload: nil)
        assert_equal false, derivation.option(:upload)
      end

      it "evaluates dynamic values" do
        @shrine.plugin :derivation_endpoint, upload_location: -> { [name, args, source] }
        derivation = @uploaded_file.derivation(:gray, "dark")
        assert_equal [:gray, ["dark"], @uploaded_file], derivation.option(:upload_location)
      end
    end
  end

  it "merges new settings with previous" do
    @shrine.plugin :derivation_endpoint, type: "text/plain"
    @shrine.derivation(:gray) { "gray" }

    @shrine.plugin :derivation_endpoint, disposition: "attachment"

    assert_equal "gray",       @shrine.derivations.fetch(:gray).call
    assert_equal "text/plain", @shrine.derivation_options.fetch(:type)
    assert_equal "attachment", @shrine.derivation_options.fetch(:disposition)
  end

  it "requires the :secret_key option" do
    assert_raises(Shrine::Error) do
      @shrine.plugin :derivation_endpoint, secret_key: nil
    end
  end
end
