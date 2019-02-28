require "./routes/base"
require "./models/album"
require "./models/photo"

module Routes
  class Albums < Base
    route do |r|
      # '/albums'
      r.is do
        # GET '/albums'
        r.get do
          albums = Album.all
          view("albums/index", locals: { albums: albums })
        end

        # POST '/albums'
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

      # GET '/albums/new'
      r.get "new" do
        album = Album.new
        view("albums/new", locals: { album: album })
      end

      # '/albums/:id'
      r.is Integer do |album_id|
        album = Album[album_id] or not_found!

        # GET '/albums/:id'
        r.get do
          view("albums/show", locals: { album: album })
        end

        # PUT '/albums/:id'
        r.put do
          album.set(params[:album])

          if album.valid?
            album.save
            r.redirect album_path(album)
          else
            view("albums/show", locals: { album: album })
          end
        end

        # DELETE '/albums/:id'
        r.delete do
          album.destroy
          r.redirect albums_path
        end
      end
    end
  end
end
