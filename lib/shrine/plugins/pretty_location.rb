# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/pretty_location.md] on GitHub.
    #
    # [doc/plugins/pretty_location.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/pretty_location.md
    module PrettyLocation
      def self.configure(uploader, opts = {})
        uploader.opts[:pretty_location] ||= { identifier: :id }
        uploader.opts[:pretty_location].merge!(opts)
      end

      module InstanceMethods
        def generate_location(io, context)
          pretty_location(io, context)
        end

        def pretty_location(io, name: nil, record: nil, version: nil, identifier: nil, **)
          if record
            namespace    = record_namespace(record)
            identifier ||= record_identifier(record)
          end

          basename = basic_location(io)
          basename = "#{version}-#{basename}" if version

          [*namespace, *identifier, *name, basename].join("/")
        end

        private

        def record_identifier(record)
          record.public_send(opts[:pretty_location][:identifier])
        end

        def record_namespace(record)
          class_name = record.class.name or return
          parts      = class_name.downcase.split("::")

          if separator = opts[:pretty_location][:namespace]
            parts.join(separator)
          else
            parts.last
          end
        end
      end
    end

    register_plugin(:pretty_location, PrettyLocation)
  end
end
