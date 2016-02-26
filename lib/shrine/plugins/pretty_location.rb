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
    #
    # By default if a record class is inside a namespace, only the "inner"
    # class name is used in the location. If you want to include the namespace,
    # you can pass in the `:namespace` option with the desired separator as the
    # value:
    #
    #     plugin :pretty_location, namespace: "_"
    #     # "blog_user/.../493g82jf23.jpg"
    #
    #     plugin :pretty_location, namespace: "/"
    #     # "blog/user/.../493g82jf23.jpg"
    module PrettyLocation
      def self.configure(uploader, namespace: nil)
        uploader.opts[:pretty_location_namespace] = namespace
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

        def generate_uid(io)
          SecureRandom.hex(5)
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
