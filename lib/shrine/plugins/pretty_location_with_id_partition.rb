class Shrine
  module Plugins
    # The `pretty_location_with_id_partition` plugin is
    # `pretty_location` plugin + id_partition (like PaperClip).
    #
    # ## Synopsis
    #
    #   plugin :pretty_location_with_id_partition [, OPTION...]
    #
    # ## Description
    #
    # This plugin uses the context information from the Attacher to try to
    # generate a nested folder structure which separates files for each record.
    # The newly generated locations will typically look like this:
    #
    #     "user/123/456/789/avatar/thumb-493g82jf23.jpg"
    #     # :model/:id_partition/:attachment/:version-:uid.:extension
    #
    # Or, you can change location by `:layout` option (see below) as follows:
    #
    #     "987/654/321/user/avatar/thumb-493g82jf23.jpg"
    #     # :reversed_id_partition/:model/:attachment/:version-:uid.:extension
    #
    # Where, reversed_id_partition means, for example, "987/654/321" when
    # integer id is 123456789.  The reason why reversing is to avoid
    # I/O workload in Amazon S3
    # ( http://docs.aws.amazon.com/AmazonS3/latest/dev/request-rate-perf-considerations.html ).
    # Of couse, if you don't use S3 or I/O workload is not an issue even if
    # using S3, and like :model prefix than :reversed_id_partition one,
    # you can overwrite 'generate_location' method.
    #
    # ### Options
    # #### namespace
    #
    # By default if a record class is inside a namespace, only the "inner"
    # class name is used in the location. If you want to include the namespace,
    # If you want to include the namespace, you can pass in the `:namespace`
    # option with the desired separator as the value.
    #
    # For example, when a model is MyEngine::BlogUser,
    #
    # * default location:
    #     plugin :pretty_location
    #     # my_engine/blog_user/.../493g82jf23.jpg
    #
    # * when namespace is "_":
    #     plugin :pretty_location, namespace: "_"
    #     # my_engine_blog_user/.../493g82jf23.jpg
    #
    # * when namespace is "/":
    #     plugin :pretty_location, namespace: "/"
    #     # my_engine/blog_user/.../493g82jf23.jpg
    #
    # #### layout
    #
    # While default location layout is :model/:id_partition/:rest
    # (where, :rest means ':attachment/:version-:uid.:extension'),
    # you can change it by 'layout' option.  For example:
    #
    #   plugin :pretty_location_with_id_partition, layout: %i(reversed_id_partition model rest)
    #   # /987/654/321/my_engine/blog_user/.../493g82jf23.jpg
    #
    # Supported keywords are :reversed_id_partition, :id_partition, :model,
    # and, :rest.
    #
    # ## NOTE
    #
    # * This plugin is inspired from
    #   https://github.com/rivnefish/rivnefish/blob/master/app/uploaders/id_partition.rb
    module PrettyLocationWithIdPartition
     #class UnsupportedIdType < StandardError; end

      def self.configure(uploader, opts = {})
        # replace 'opt' to 'pretty_location_with_id_partition_opt'
        conf_wip(uploader, opts, :namespace)
        conf_wip(uploader, opts, :layout,   %i(model id_partition rest))
      end

      # private

      def self.conf_wip(uploader, opts, key, default = nil)
        new_key = key_wip(key)
        uploader.opts[new_key] = opts.fetch(key, uploader.opts[new_key] || default)
      end

      def self.key_wip(key)
        ('pretty_location_with_id_partition' + key.to_s).to_sym
      end

      module InstanceMethods
        def generate_location(io, context)
          if context[:record]
            model = model_location(context[:record].class) if context[:record].class.name
          end
          name = context[:name]

          dirname, slash, basename = super.rpartition("/")
          basename = "#{context[:version]}-#{basename}" if context[:version]
          original = dirname + slash + basename

          result = []
          for entry in opt_wip(:layout) do
            case entry
            when :reversed_id_partition
              if context[:record].respond_to?(:id)
                result << id_partition(context[:record].id, true)
              end
            when :id_partition
              if context[:record].respond_to?(:id)
                result << id_partition(context[:record].id, false)
              end
            when :model
              result << model
            when :rest
              result << name
              result << original
            else
              raise "unsupported layout entry '#{entry}'"
            end
          end
          result.compact.join("/")
        end

        private

        def key_wip(key)
          PrettyLocationWithIdPartition.key_wip(key)
        end

        def opt_wip(key)
          opts[key_wip(key)]
        end

        # Rails' underscore with split by '::'
        def underscore(camel_cased_word)
          word = camel_cased_word.to_s.dup
          word = word.split('::')

          for w in word do
            w.gsub!(/(?:([A-Za-z\d])|^)(\d+})(?=\b|[^a-z])/) { "#{$1}#{$1 && '_'}#{$2.downcase}" }
            w.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
            w.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
            w.tr!("-", "_")
            w.downcase!
          end
          word
        end

        def model_location(klass)
          parts = underscore(klass.name)
          if (separator = opt_wip(:namespace))
            parts.join(separator)
          else
            parts.last
          end
        end

        # generate (reversed) id_partition from id when integer
        def id_partition(id, reverse)
          case id
          when Integer
            str_id = "%09d".freeze % id
            str_id = str_id.reverse if reverse
            str_id.scan(/\d{3}/).join("/".freeze)
          when String
            id.scan(/.{3}/).first(3).join("/".freeze)
          else
            # NOTE: 'raise' cannot be used.  It fails on save.
            nil
          end
        end

        def reverse?
          layout_opt = opt_wip(:layout)
          !layout_opt.index(:id_partition) ||
           layout_opt.index(:reversed_id_partition)
        end
      end
    end

    register_plugin(:pretty_location_with_id_partition, PrettyLocationWithIdPartition)
  end
end
