class Shrine
  module Plugins
    # The pretty_location plugin attempts to generate a nicer folder structure
    # for uploaded files.
    #
    #     plugin :pretty_location
    #
    # This plugin uses the context information from the Attacher to try to
    # generate a nested folder structure which separates files for each record.
    # The newly generated locations will typically look like this:
    #
    #     "user/564/avatar/thumb-493g82jf23.jpg"
    #     # :model/:id/:attachment/:version-:uid.:extension
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

        private

        def generate_uid(io)
          SecureRandom.hex(5)
        end
      end
    end

    register_plugin(:pretty_location, PrettyLocation)
  end
end
