require "roda"

require "./config/shrine"

Shrine.plugin :upload_endpoint
Shrine.plugin :presign_endpoint, presign: -> (id, options, request) do
  Struct.new(:url, :fields).new("#{request.base_url}/s3", { "key" => "cache/#{id}" })
end

class FakeS3 < Roda
  plugin :middleware

  route do |r|
    r.is "s3" do
      fake_s3 = Shrine.upload_endpoint(:cache, upload_context: -> (request) {
        { location: request.params["key"].match(/^cache\//).post_match }
      })

      r.run fake_s3
    end
  end
end

ShrineDemo.plugin :csrf, skip: ["POST:/s3"]
