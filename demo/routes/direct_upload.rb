require "./routes/base"
require "./config/shrine"

module Routes
  class DirectUpload < Base
    if production?
      route do |r|
        # all '/presign'
        r.is "presign" do
          r.run Shrine.presign_endpoint(:cache)
        end
      end
    else
      # In development and test environment we're using filesystem storage
      # for speed, so on the client side we'll upload files to our app.
      route do |r|
        # all '/upload'
        r.is "upload" do
          r.run Shrine.upload_endpoint(:cache)
        end
      end
    end
  end
end
