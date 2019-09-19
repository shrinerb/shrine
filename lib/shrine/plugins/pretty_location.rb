# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/pretty_location.md] on GitHub.
    #
    # [doc/plugins/pretty_location.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/pretty_location.md
    module PrettyLocation
      def self.configure(uploader, **opts)
        uploader.opts[:pretty_location] ||= { identifier: :id, class_transform: :downcase }
        uploader.opts[:pretty_location].merge!(opts)
      end

      module InstanceMethods
        def generate_location(io, **options)
          pretty_location(io, options)
        end

        def pretty_location(io, name: nil, record: nil, version: nil, derivative: nil, identifier: nil, metadata: {}, **)
          if record
            namespace    = record_namespace(record)
            identifier ||= record_identifier(record)
          end

          basename = basic_location(io, metadata: metadata)
          basename = [*(version || derivative), basename].join("-")

          [*namespace, *identifier, *name, basename].join("/")
        end

        private

        def record_identifier(record)
          record.public_send(opts[:pretty_location][:identifier])
        end

        def transform_class_name(class_name)
          class_transform = opts[:pretty_location][:class_transform]

          if class_transform.respond_to?(:call)
            class_transform.call(class_name)
          else
            class_name.send(class_transform)
          end
        end

        def record_namespace(record)
          class_name = record.class.name or return
          parts      = transform_class_name(class_name).split("::")

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
