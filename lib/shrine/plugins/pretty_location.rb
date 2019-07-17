# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/pretty_location.md] on GitHub.
    #
    # [doc/plugins/pretty_location.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/pretty_location.md
    module PrettyLocation
      def self.configure(uploader, opts = {})
        uploader.opts[:pretty_location_namespace] = opts.fetch(:namespace, uploader.opts[:pretty_location_namespace])
        uploader.opts[:pretty_location_identifier] = opts.fetch(:identifier, uploader.opts[:pretty_location_identifier])
      end

      module InstanceMethods
        def generate_location(io, context)
          identifier = record_identifier(context[:record], opts[:pretty_location_identifier])
          pretty_location(io, context, identifier: identifier)
        end

        def pretty_location(io, context = {}, identifier:)
          if context[:record]
            type = class_location(context[:record].class) if context[:record].class.name
          end
          name = context[:name]

          dirname, slash, basename = basic_location(io).rpartition("/")
          basename = "#{context[:version]}-#{basename}" if context[:version]
          original = dirname + slash + basename

          [type, identifier, name, original].compact.join("/")
        end

        private

        def record_identifier(record, method)
          return unless record

          if method
            record.send(method)
          else
            record.id
          end
        end

        def class_location(klass)
          parts = klass.name.downcase.split("::")
          if separator = opts[:pretty_location_namespace]
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
