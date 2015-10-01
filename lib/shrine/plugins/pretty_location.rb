class Shrine
  module Plugins
    module PrettyLocation
      module InstanceMethods
        def generate_location(io, context)
          type = context[:record].class.name.downcase if context[:record] && context[:record].class.name
          id   = context[:record].id if context[:record].respond_to?(:id)
          name = context[:name]

          dirname, slash, basename = super.rpartition("/")
          basename = "#{context[:version]}-#{basename}" if context[:version]
          original = dirname + slash + basename

          [type, id, name, original].compact.join("/")
        end
      end
    end

    register_plugin(:pretty_location, PrettyLocation)
  end
end
