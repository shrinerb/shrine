require "./routes/base"
require "./models/album"
require "./models/photo"

module Routes
  class Albums < Base
    route do |r|
      r.is do
        r.get do
          albums = Album.all
          view("albums/index", locals: { albums: albums })
        end

        r.post do
          album = Album.new(params[:album])
          if album.valid?
            album.save
            r.redirect album_path(album)
          else
            view("albums/new", locals: { album: album })
          end
        end
      end

      r.get "new" do
        album = Album.new
        view("albums/new", locals: { album: album })
      end

      r.is Integer do |album_id|
        album = Album[album_id] or not_found!

        r.get do
          view("albums/show", locals: { album: album })
        end

        r.put do
          album.set(params[:album])
          if album.valid?
            album.save
            r.redirect album_path(album)
          else
            view("albums/show", locals: { album: album })
          end
        end

        r.delete do
          album.destroy
          r.redirect albums_path
        end
      end
    end
  end
end
