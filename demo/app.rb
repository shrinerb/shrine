require "roda"

require "./routes/albums"
require "./routes/direct_upload"

class ShrineDemo < Roda
  plugin :public
  plugin :assets, css: "app.css", js: "app.js"
  plugin :run_handler

  use Rack::Session::Cookie, secret: "secret"
  plugin :route_csrf, check_header: true

  route do |r|
    r.public # serve static assets
    r.assets # serve dynamic assets

    check_csrf!

    # redirect '/' to '/albums'
    r.root do
      r.redirect "/albums", 301
    end

    # all '/albums'
    r.on "albums" do
      r.run Routes::Albums
    end

    # all other routes
    r.run Routes::DirectUpload, not_found: :pass
  end
end
