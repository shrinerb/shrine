# frozen_string_literal: true

require "base64"
require "json"

class Shrine
  module Plugins
    # The `urlsafe_serialization` plugin provides the ability to serialize and
    # deserialize a `Shrine::UploadedFile` in a way that's suitable for
    # including in a URL. This is a private plugin used by the
    # `download_endpoint` plugin.
    #
    #     plugin :_urlsafe_serialization
    #
    # The plugin defines `urlsafe_dump` and `urlsafe_load` methods on
    # `Shrine::UploadedFile`. The file is first serialized to JSON, then
    # encoded with base64.
    #
    #     serialized = uploaded_file.urlsafe_dump
    #     # or
    #     serialized = MyUploader::UploadedFile.urlsafe_dump(uploaded_file)
    #     serialized #=> "eyJpZCI6IjlhZGM0NmIzZjI..."
    #
    #     # ...
    #
    #     uploaded_file = MyUploader::UploadedFile.urlsafe_load(serialized)
    #     uploaded_file #=> #<MyUploader::UploadedFile>
    #
    # ## Metadata
    #
    # By default no metadata is included in the serialization:
    #
    #     uploaded_file.metadata #=> { ... metadata ... }
    #
    #     serialized    = MyUploader::UploadedFile.urlsafe_dump(uploaded_file)
    #     uploaded_file = MyUploader::UploadedFile.urlsafe_load(serialized)
    #
    #     uploaded_file.metadata #=> {}
    #
    # The `:metadata` option can be used to specify metadata you want to
    # serialize:
    #
    #     serialized    = MyUploader::UploadedFile.urlsafe_dump(uploaded_file, metadata: %w[size mime_type])
    #     uploaded_file = MyUploader::UploadedFile.urlsafe_load(serialized)
    #
    #     uploaded_file.metadata #=> { "size" => 4394, "mime_type" => "image/jpeg" }
    module UrlsafeSerialization
      module ClassMethods
        def urlsafe_serialize(hash)
          urlsafe_serializer.encode(hash)
        end

        def urlsafe_deserialize(string)
          urlsafe_serializer.decode(string)
        end

        def urlsafe_serializer
          Serializer.new
        end
      end

      module FileMethods
        def urlsafe_dump(**options)
          self.class.urlsafe_dump(self, **options)
        end

        def urlsafe_data(metadata: [])
          data = self.data.dup

          if metadata.any?
            # order metadata in the specified order
            data["metadata"] = metadata
              .map { |name| [name, self.metadata[name]] }
              .to_h
          else
            # save precious characters
            data.delete("metadata")
          end

          data
        end
      end

      module FileClassMethods
        def urlsafe_dump(file, **options)
          data = file.urlsafe_data(**options)

          shrine_class.urlsafe_serialize(data)
        end

        def urlsafe_load(string)
          data = shrine_class.urlsafe_deserialize(string)

          new(data)
        end
      end

      class Serializer
        def encode(data)
          base64_encode(json_encode(data))
        end

        def decode(data)
          json_decode(base64_decode(data))
        end

        private

        def json_encode(data)
          JSON.generate(data)
        end

        def base64_encode(data)
          Base64.urlsafe_encode64(data, padding: false)
        end

        def base64_decode(data)
          Base64.urlsafe_decode64(data)
        end

        def json_decode(data)
          JSON.parse(data)
        end
      end
    end

    register_plugin(:_urlsafe_serialization, UrlsafeSerialization)
  end
end
