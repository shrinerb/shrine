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
          default_identifier = :id
          param_identifier   = opts[:pretty_location_identifier]

          if param_identifier && context[:record].respond_to?(param_identifier)
            identifier = context[:record].public_send(param_identifier)
          elsif context[:record].respond_to?(default_identifier)
            identifier = context[:record].public_send(default_identifier)
          else
            identifier = nil
          end

          pretty_location(io, identifier, context)
        end

        def pretty_location(io, identifier, context = {})
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
