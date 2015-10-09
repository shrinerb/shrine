require "roda"
require "json"
require "forwardable"

class Shrine
  module Plugins
    # The direct_upload plugin gives you a Rack endpoint (implemented in
    # [Roda]) which you can use to implement AJAX uploads.
    #
    #     plugin :direct_upload, max_size: 20*1024*1024
    #
    # This is how you could mount the endpoint in a Rails application:
    #
    #     Rails.application.routes.draw do
    #       mount ImageUploader.direct_endpoint => "/attachments/images"
    #     end
    #
    # Note that you should mount a separate endpoint for each uploader that you
    # want to use it with. This now gives your Ruby application a
    # `/attachments/images/:storage/:name` route, which accepts POST requests
    # with a "file" query parameter:
    #
    #     $ curl -F "file=@/path/to/avatar.jpg" localhost:3000/attachments/images/cache/avatar
    #     # {"id":"43kewit94.jpg","storage":"cache","metadata":{...}}
    #
    # The endpoint returns all responses in JSON format. This endpoint is
    # typically useful for implementing AJAX uploads. There are many great
    # JavaScript libraries for AJAX file uploads, so for example if we have
    # this form:
    #
    #     <%= form_for @user do |f| %>
    #       <%= f.hidden_field :avatar, value: @user.avatar_data %>
    #       <%= f.file_field :avatar %>
    #     <% end %>
    #
    # this is how we could use [jQuery-File-Upload] to enable direct AJAX
    # uploads:
    #
    #     $('[type="file"]').fileupload({
    #       url '/attachments/images/cache/avatar',
    #       paramName: 'file',
    #       done: function(e, data) { $(this).prev().value(data.result) }
    #     });
    #
    # Now whenever a file gets chosen, the upload will automatically start in
    # the background. It's typically good to show a progress bar to the user,
    # which jQuery-File-Upload supports. After the upload has finished, the
    # uploaded file JSON is written to the hidden field, and will be sent on
    # form submit.
    #
    # The `:storage` is typically "cache", but you can also use it with
    # "store", you just need to first add it to allowed storages:
    #
    #     plugin :direct_upload, allowed_storages: [:cache, :store]
    #
    # It's typically good to limit the file size using the `:max_size` option,
    # so if the file is too big, the endpoint will automatically delete the
    # file and return a 413 response. However, if for whatever reason you don't
    # want to impose a limit on filesize, you can set the option to nil.
    #
    #     plugin :direct_upload, max_size: nil
    #
    # [Roda]: https://github.com/jeremyevans/roda
    # [jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
    module DirectUpload
      def self.configure(uploader, allowed_storages: [:cache], max_size:)
        uploader.opts[:direct_upload_allowed_storages] = allowed_storages
        uploader.opts[:direct_upload_max_size] = max_size
      end

      module ClassMethods
        def direct_endpoint
          @direct_endpoint ||= build_direct_endpoint
        end

        private

        def build_direct_endpoint
          app = Class.new(App)
          app.opts[:shrine_class] = self
          app.app
        end
      end

      class App < Roda
        plugin :default_headers, "Content-Type"=>"application/json"
        plugin :halt

        route do |r|
          r.on ":storage" do |storage_key|
            allow_storage!(storage_key)
            @uploader = shrine_class.new(storage_key.to_sym)

            r.post ":name" do |name|
              file = get_file
              context = {name: name, phase: :direct}

              json @uploader.upload(file, context)
            end
          end
        end

        def json(object)
          object.to_json
        end

        def allow_storage!(storage)
          if !allowed_storages.map(&:to_s).include?(storage)
            error! 403, "Storage #{storage.inspect} is not allowed."
          end
        end

        def get_file
          file = require_param!("file")
          error! 400, "The \"file\" query parameter is not a file." if !(file.is_a?(Hash) && file.key?(:tempfile))
          check_filesize!(file[:tempfile]) if max_size

          RackFile.new(file)
        end

        def check_filesize!(file)
          if file.size > max_size
            file.delete
            megabytes = max_size.to_f / 1024 / 1024
            error! 413, "The file is too big (maximum size is #{megabytes} MB)."
          end
        end

        def require_param!(name)
          request.params.fetch(name)
        rescue KeyError
          error! 400, "Missing query parameter: #{name.inspect}"
        end

        def error!(status, message)
          request.halt status, {error: message}.to_json
        end

        def shrine_class
          opts[:shrine_class]
        end

        def allowed_storages
          shrine_class.opts[:direct_upload_allowed_storages]
        end

        def max_size
          shrine_class.opts[:direct_upload_max_size]
        end
      end

      class RackFile
        attr_reader :original_filename, :content_type
        attr_accessor :tempfile

        def initialize(tempfile:, filename: nil, type: nil, **)
          @tempfile          = tempfile
          @original_filename = filename
          @content_type      = type
        end

        def path
          @tempfile.path
        end

        def to_io
          @tempfile
        end

        extend Forwardable
        delegate Shrine::IO_METHODS.keys => :@tempfile
      end
    end

    register_plugin(:direct_upload, DirectUpload)
  end
end
