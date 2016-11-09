class Shrine
  module Plugins
    # The `default_url` plugin allows setting the URL which will be returned when
    # the attachment is missing.
    #
    #     plugin :default_url
    #
    #     Attacher.default_url do |options|
    #       "/#{name}/missing.jpg"
    #     end
    #
    # `Attacher#url` returns the default URL when attachment is missing. Any
    # passed in URL options will be present in the `options` hash.
    #
    #     attacher.url #=> "/avatar/missing.jpg"
    #     # or
    #     user.avatar_url #=> "/avatar/missing.jpg"
    #
    # The default URL block is evaluated in the context of an instance of
    # `Shrine::Attacher`.
    #
    #     Attacher.default_url do |options|
    #       self #=> #<Shrine::Attacher>
    #
    #       name   #=> :avatar
    #       record #=> #<User>
    #     end
    module DefaultUrl
      def self.configure(uploader, &block)
        if block
          uploader.opts[:default_url] = block
          warn "Passing a block to default_url Shrine plugin is deprecated and will probably be removed in future versions of Shrine. Use `Attacher.default_url { ... }` instead."
        end
      end

      module AttacherClassMethods
        def default_url(&block)
          shrine_class.opts[:default_url_block] = block
        end
      end

      module AttacherMethods
        def url(**options)
          super || default_url(**options)
        end

        private

        def default_url(**options)
          if default_url_block
            instance_exec(options, &default_url_block)
          elsif shrine_class.opts[:default_url]
            shrine_class.opts[:default_url].call(context.merge(options){|k,old,new|old})
          end
        end

        def default_url_block
          shrine_class.opts[:default_url_block]
        end
      end
    end

    register_plugin(:default_url, DefaultUrl)
  end
end
