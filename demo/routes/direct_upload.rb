require "./routes/base"
require "./config/shrine"

module Routes
  class DirectUpload < Base
    if production?
      route do |r|
        # Only '/presign'
        r.is "presign" do
          # GET /presign
          r.run Shrine.presign_endpoint(:cache)
        end
      end
    else
      # In development and test environment we're using filesystem storage
      # for speed, so on the client side we'll upload files to our app.
      route do |r|
        # Only '/upload'
        r.is "upload" do
          # POST /upload
          r.run Shrine.upload_endpoint(:cache)
        end
      end
    end
  end
end
