require "roda"

require "./routes/albums"
require "./routes/direct_upload"

class ShrineDemo < Roda
  plugin :public
  plugin :assets, css: "app.css", js: "app.js"
  plugin :run_handler

  route do |r|
    r.public # serve static assets
    r.assets # serve dynamic assets

    r.root do
      r.redirect "/albums", 301
    end

    r.on "albums" do
      r.run Routes::Albums
    end

    r.run Routes::DirectUpload, not_found: :pass
  end
end
