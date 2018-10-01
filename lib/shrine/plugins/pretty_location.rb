# frozen_string_literal: true

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
    # ## Performance on AWS S3
    #
    # AWS S3 has [guidelines] on folder structure to optimize storage performance
    # for very high request rate applications by using a random prefix at the
    # beginning of the folder structure. For example, if you wanted to use pretty
    # location with a prefix, you can do that by overriding the
    # `generate_location` method as shown in the [Readme] and return an
    # appropriate file location. For example:
    #
    #     def generate_location
    #       if context[:record]
    #         type = class_location(context[:record].class) if context[:record].class.name
    #         id   = context[:record].id if context[:record].respond_to?(:id)
    #       end
    #       name = context[:name]
    #
    #       dirname, slash, basename = super.rpartition("/")
    #       basename = "#{context[:version]}-#{basename}" if context[:version]
    #       original = dirname + slash + basename
    #
    #       [SecureRandom.hex(2), type, id, name, original].compact.join("/")
    #     end
    #     # "2af7/blog_user/.../493g82jf23.jpg"
    #
    # [guidelines]: https://docs.aws.amazon.com/AmazonS3/latest/dev/request-rate-perf-considerations.html
    # [Readme]: https://github.com/shrinerb/shrine#location
    #
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
