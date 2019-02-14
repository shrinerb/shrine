# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/pretty_location.md] on GitHub.
    #
    # [doc/plugins/pretty_location.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/pretty_location.md
    module PrettyLocation
      def self.configure(uploader, opts = {})
        uploader.opts[:pretty_location_namespace] = opts.fetch(:namespace, uploader.opts[:pretty_location_namespace])
      end

      module InstanceMethods
        def generate_location(io, context)
          if context[:record]
            type = class_location(context[:record].class) if context[:record].class.name
            id   = context[:record].id if context[:record].respond_to?(:id)
          end
          name = context[:name]

          dirname, slash, basename = super.rpartition("/")
          basename = "#{context[:version]}-#{basename}" if context[:version]
          original = dirname + slash + basename

          [type, id, name, original].compact.join("/")
        end

        private

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
