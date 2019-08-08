# frozen_string_literal: true

require "json"

class Shrine
  module Plugins
    # This plugin provides methods for parsing and generating column data,
    # without any logic for actually integrating with an entity instance. The
    # user can use this functionality if they want to implement their own
    # integration with their database library.
    #
    #     class Photo
    #       include Shrine::Attachment(:image)
    #
    #       extend Dry::Initializer
    #       option :image_data
    #     end
    #
    #     attacher = Shrine::Attacher.new
    #     attacher.attach(io)
    #
    #     photo = Photo.new(image_data: attacher.column_value)
    #     photo.image #=> #<Shrine::UploadedFile>
    #
    #     # ...
    #
    #     attacher = Shrine::Attacher.from_column(photo.image_data)
    #     attacher.file #=> #<Shrine::UploadedFile>
    module Column
      def self.configure(uploader, **opts)
        uploader.opts[:column] ||= { serializer: JsonSerializer.new(JSON) }
        uploader.opts[:column].merge!(opts)
      end

      module AttacherClassMethods
        # Initializes the attacher from a data hash/string expected to come
        # from a database record column.
        #
        #     Attacher.from_column('{"id":"...","storage":"...","metadata":{...}}')
        def from_column(data, **options)
          attacher = new(**options)
          attacher.load_column(data)
          attacher
        end
      end

      module AttacherMethods
        # Column serializer object.
        attr_reader :column_serializer

        # Allows overriding the default column serializer.
        def initialize(column_serializer: shrine_class.opts[:column][:serializer], **options)
          super(**options)
          @column_serializer = column_serializer
        end

        # Loads attachment from column data.
        #
        #     attacher.file #=> nil
        #     attacher.load_column('{"id":"...","storage":"...","metadata":{...}}')
        #     attacher.file #=> #<Shrine::UploadedFile>
        def load_column(data)
          load_data(deserialize_column(data))
        end

        # Returns column data as a serialized string (JSON by default).
        #
        #     attacher.column_value #=> '{"id":"...","storage":"...","metadata":{...}}'
        def column_value
          serialize_column(data)
        end

        private

        # Converts the column data hash into a string (generates JSON by
        # default).
        #
        #     Attacher.serialize_column({ "id" => "...", "storage" => "...", "metadata" => { ... } })
        #     #=> '{"id":"...","storage":"...","metadata":{...}}'
        #
        #     Attacher.serialize_column(nil)
        #     #=> nil
        def serialize_column(data)
          return data unless column_serializer && data

          column_serializer.dump(data)
        end

        # Converts the column data string into a hash (parses JSON by default).
        #
        #     Attacher.deserialize_column('{"id":"...","storage":"...","metadata":{...}}')
        #     #=> { "id" => "...", "storage" => "...", "metadata" => { ... } }
        #
        #     Attacher.deserialize_column(nil)
        #     #=> nil
        def deserialize_column(data)
          return data unless column_serializer && data

          column_serializer.load(data)
        end
      end

      # JSON.dump and JSON.load shouldn't be used with untrusted input, so we
      # create this wrapper class which calls JSON.generate and JSON.parse
      # instead.
      class JsonSerializer
        def initialize(json)
          @json = json
        end

        def dump(data)
          @json.generate(data)
        end

        def load(data)
          @json.parse(data)
        end
      end
    end

    register_plugin(:column, Column)
  end
end
