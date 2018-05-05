require "roda"

module Routes
  class Base < Roda
    plugin :environments

    plugin :render
    plugin :forme
    plugin :partials
    plugin :assets, css: "app.css", js: "app.js"

    use Rack::MethodOverride
    plugin :all_verbs

    use Rack::Session::Cookie, secret: "secret"
    plugin :csrf, raise: true

    plugin :indifferent_params
    plugin :path

    path(:albums,          "/albums")
    path(:new_album,       "/albums/new")
    path(:album) { |album| "/albums/#{album.id}" }

    def not_found!
      response.status = 404
      request.halt
    end

    def upload_server
      if self.class.production?
        :s3
      else
        :app
      end
    end
  end
end
