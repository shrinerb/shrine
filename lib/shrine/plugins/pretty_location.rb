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
    # contains the ':owner_type', whic may be 'User', and the ':owner_id'
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
          name = context[:name]

          dirname, slash, basename = super.rpartition("/")
          basename = "#{context[:version]}-#{basename}" if context[:version]
          original = dirname + slash + basename

          [type, id, name, original].compact.join("/")
        end

        private

        attr_reader :owner, :record

        def type_string
          if @owner = opts[:pretty_location_owner]
            owner.downcase!
            str = owner_class_and_id_string
          end

          (str || '') << class_location(record.class) if record.class.name
        end

        def class_location(klass)
          parts = klass.name.downcase.split("::")
          if separator = opts[:pretty_location_namespace]
            parts.join(separator)
          else
            parts.last
          end
        end

        def owner_class_and_id_string
          # First the polymorphic association should be checked, because
          # the record will respond to "#{owner}_id" in both cases
          if record.respond_to?("#{owner}_type")
            owner_string = record.__send__("#{owner}_type")
            owner_id = record.__send__("#{owner}_id".to_sym)
          elsif record.respond_to?("#{owner}_id")
            owner_string = owner
            owner_id = record.__send__("#{owner}_id".to_sym)
          end
          str = "#{owner_string.downcase}/" if owner_string
          (str || '') << "#{owner_id}/" if owner_id
        end
      end
    end

    register_plugin(:pretty_location, PrettyLocation)
  end
end
