require "test_helper"
require "shrine/plugins/presign_endpoint"
require "shrine/storage/s3"
require "rack/test_app"
require "json"
require "ostruct"

describe Shrine::Plugins::PresignEndpoint do
  def app
    Rack::TestApp.wrap(Rack::Lint.new(endpoint))
  end

  def endpoint
    @uploader.class.presign_endpoint(:cache)
  end

  before do
    @uploader = uploader { plugin :presign_endpoint }
    @uploader.class.storages[:cache] = Shrine::Storage::S3.new(bucket: "foo", stub_responses: true)
  end

  it "returns a JSON response" do
    response = app.get "/"

    assert_equal 200, response.status

    assert_equal "application/json",                 response.headers["Content-Type"]
    assert_equal response.body_binary.bytesize.to_s, response.headers["Content-Length"]
    assert_equal "no-store",                         response.headers["Cache-Control"]

    assert_instance_of String, response.body_json["url"]
    assert_instance_of Hash,   response.body_json["fields"]
    assert_instance_of Hash,   response.body_json["headers"]
  end

  it "uses extension from given filename" do
    response = app.get "/?filename=nature.jpg"
    assert_match /\.jpg$/, response.body_json["fields"]["key"]
  end

  it "accepts presign location" do
    @uploader.class.plugin :presign_endpoint, presign_location: -> (r) { "${filename}" }
    response = app.get "/"
    assert_match "${filename}", response.body_json["fields"]["key"]
  end

  it "accepts presign options" do
    @uploader.class.plugin :presign_endpoint, presign_options: { content_type: "image/jpeg" }
    response = app.get "/"
    assert_equal "image/jpeg", response.body_json["fields"]["Content-Type"]

    @uploader.class.plugin :presign_endpoint, presign_options: -> (r) { {content_type: "image/jpeg"} }
    response = app.get "/"
    assert_equal "image/jpeg", response.body_json["fields"]["Content-Type"]
  end

  it "accepts presign proc" do
    @uploader.class.plugin :presign_endpoint,
      presign_options: { content_type: "image/jpeg" },
      presign: -> (i, o, r) { OpenStruct.new(url: "foo", fields: o) }
    response = app.get "/"
    assert_match "foo",        response.body_json["url"]
    assert_equal "image/jpeg", response.body_json["fields"]["content_type"]
    assert_equal Hash.new,     response.body_json["headers"]
  end

  it "allows presigns to provide headers" do
    @uploader.class.plugin :presign_endpoint,
      presign_options: { content_type: "image/jpeg" },
      presign: -> (i, o, r) { OpenStruct.new(url: "foo", fields: {}, headers: {"foo" => "bar"}) }
    response = app.get "/"
    assert_equal Hash["foo" => "bar"], response.body_json["headers"]
  end

  it "accepts response proc" do
    @uploader.class.plugin :presign_endpoint, rack_response: -> (o, r) do
      [200, {"Content-Type" => "application/vnd.api+json"}, [{data: o}.to_json]]
    end
    response = app.get "/"
    assert_equal ["url", "fields", "headers"], JSON.parse(response.body_binary)["data"].keys
    assert_equal "application/vnd.api+json", response.headers["Content-Type"]
  end

  it "allows overriding Cache-Control" do
    @uploader.class.plugin :presign_endpoint, rack_response: -> (o, r) do
      [200, {"Content-Type" => "application/json", "Cache-Control" => "no-cache"}, [o.to_json]]
    end
    response = app.get "/"
    assert_equal "no-cache", response.headers["Cache-Control"]
  end

  it "allows overriding options when instantiating the endpoint" do
    app = Rack::TestApp.wrap(@uploader.class.presign_endpoint(:cache, presign_options: { content_type: "image/jpeg" }))
    response = app.get "/"
    assert_equal "image/jpeg", response.body_json["fields"]["Content-Type"]
  end

  it "accepts only POST requests" do
    response = app.put "/"
    assert_equal 405, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Method Not Allowed", response.body_binary
  end

  it "accepts only root requests" do
    response = app.get "/presign"
    assert_equal 404, response.status
  end
end
