class Shrine
  module Plugins
    # The `pretty_location` plugin attempts to generate a nicer folder structure
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
    #
    # A resource owner could be specified via ':owner' option.
    # Then all the resources would be included into owner's folder.
    #
    # When the owner is a direct association, i.e. the ':blog' model
    # contains the ':user_id':
    #
    #     plugin :pretty_location, namespace: "_", owner: "User"
    #     # "user/1/blog_user/.../493g82jf23.jpg"
    #
    # Also, when the owner is a polymorphic association, i.e. the ':blog' model
    # contains the ':owner_type', which may be 'User', and the ':owner_id'
    #
    #     plugin :pretty_location, namespace: "_", owner: "Owner"
    #     # "user/1/blog_user/.../493g82jf23.jpg"
    module PrettyLocation
      def self.configure(uploader, opts = {})
        uploader.opts[:pretty_location_namespace] = opts.fetch(:namespace, uploader.opts[:pretty_location_namespace])
        uploader.opts[:pretty_location_owner] = opts.fetch(:owner, uploader.opts[:pretty_location_owner])
      end

      module InstanceMethods
        def generate_location(_io, context)
          if @record = context[:record]
            type = type_string
            id   = record.id if record.respond_to?(:id)
          end

          dirname, slash, basename = super.rpartition('/')
          basename = "#{context[:version]}-#{basename}" if context[:version]
          original = dirname + slash + basename

          [type, id, context[:name], original].compact.join('/')
        end

        private

        attr_reader :owner, :record

        def type_string
          ((@owner = opts[:pretty_location_owner]) ? owner_class_and_id_string : '') << class_location(record.class) if record.class.name
        end

        def class_location(klass)
          (separator = opts[:pretty_location_namespace]) ? klass.name.downcase.split('::').join(separator) : klass.name.downcase.split('::').last
        end

        def owner_class_and_id_string
          owner.downcase!

          # If owner is a polymorphic association, then fetch owner's class,
          # else, use the specified owner string from opts[:pretty_location_owner]
          (owner_class_string || '') << "#{record.__send__("#{owner}_id".to_s)}/" if record.respond_to?("#{owner}_id")
        end

        def owner_class_string
          "#{(record.respond_to?("#{owner}_type") ? record.__send__("#{owner}_type") : owner).downcase}/"
        end
      end
    end

    register_plugin(:pretty_location, PrettyLocation)
  end
end
