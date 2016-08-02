require "roda"
require "tilt/erb"

require "./models/album"
require "./models/photo"

class ShrineDemo < Roda
  plugin :public

  plugin :render
  plugin :partials

  use Rack::MethodOverride
  plugin :all_verbs

  use Rack::Session::Cookie, secret: "secret"
  plugin :csrf, raise: true

  plugin :indifferent_params

  route do |r|
    r.public # route static assets

    r.on "images" do
      r.run ImageUploader::UploadEndpoint
    end

    @album = Album.first || Album.create(name: "My Album")

    r.root do
      view(:index)
    end

    r.put "album" do
      @album.update(params[:album])
      r.redirect r.referer
    end

    r.post "album/photos" do
      photo = @album.add_photo(params[:photo])
      partial("photo", locals: {photo: photo, idx: @album.photos.count})
    end
  end
end
