# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/type_predicates
    module TypePredicates
      def self.configure(uploader, methods: [], **opts)
        uploader.opts[:type_predicates] ||= { mime: :mini_mime }
        uploader.opts[:type_predicates].merge!(opts)

        methods.each do |name|
          uploader::UploadedFile.send(:define_method, "#{name}?") { type?(name) }
        end
      end

      module ClassMethods
        def type_lookup(extension, database = nil)
          database ||= opts[:type_predicates][:mime]
          database   = MimeDatabase.new(database) if database.is_a?(Symbol)
          database.call(extension.to_s)
        end
      end

      module FileMethods
        def image?
          general_type?("image")
        end

        def video?
          general_type?("video")
        end

        def audio?
          general_type?("audio")
        end

        def text?
          general_type?("text")
        end

        def type?(type)
          matching_mime_type = shrine_class.type_lookup(type)

          fail Error, "type #{type.inspect} is not recognized by the MIME library" unless matching_mime_type

          mime_type! == matching_mime_type
        end

        private

        def general_type?(type)
          mime_type!.start_with?(type)
        end

        def mime_type!
          mime_type or fail Error, "mime_type metadata value is missing"
        end
      end

      class MimeDatabase
        SUPPORTED_TOOLS = %i[mini_mime mime_types mimemagic marcel rack_mime]

        def initialize(tool)
          raise Error, "unknown type database #{tool.inspect}, supported databases are: #{SUPPORTED_TOOLS.join(",")}" unless SUPPORTED_TOOLS.include?(tool)

          @tool = tool
        end

        def call(extension)
          send(:"lookup_with_#{@tool}", extension)
        end

        private

        def lookup_with_mini_mime(extension)
          require "mini_mime"

          info = MiniMime.lookup_by_extension(extension)
          info&.content_type
        end

        def lookup_with_mime_types(extension)
          require "mime/types"

          mime_type = MIME::Types.of(".#{extension}").first
          mime_type&.content_type
        end

        def lookup_with_mimemagic(extension)
          require "mimemagic"

          magic = MimeMagic.by_extension(".#{extension}")
          magic&.type
        end

        def lookup_with_marcel(extension)
          require "marcel"

          type = Marcel::MimeType.for(extension: ".#{extension}")
          type unless type == "application/octet-stream"
        end

        def lookup_with_rack_mime(extension)
          require "rack/mime"

          Rack::Mime.mime_type(".#{extension}", nil)
        end
      end
    end

    register_plugin(:type_predicates, TypePredicates)
  end
end
