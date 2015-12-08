class Shrine
  module Plugins
    # The default_url plugin allows setting the URL which will be returned when
    # the attachment is missing.
    #
    #     plugin :default_url do |context|
    #       "/#{context[:name]}/missing.jpg"
    #     end
    #
    # The default URL gets triggered when calling `<attachment>_url` on the
    # model:
    #
    #     user.avatar     #=> nil
    #     user.avatar_url # "/avatar/missing.jpg"
    #
    # Any additional URL options will be present in the `context` hash.
    module DefaultUrl
      def self.configure(uploader, &block)
        uploader.opts[:default_url] = block
      end

      module AttacherMethods
        private

        def default_url(**options)
          default_url_block.call(options.merge(context))
        end

        def default_url_block
          shrine_class.opts[:default_url]
        end
      end
    end

    register_plugin(:default_url, DefaultUrl)
  end
end
