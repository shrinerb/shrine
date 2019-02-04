# frozen_string_literal: true

class Shrine
  module Plugins
    module DefaultUrl
      def self.configure(uploader, &block)
        if block
          uploader.opts[:default_url] = block
          Shrine.deprecation("Passing a block to default_url plugin is deprecated and will probably be removed in future versions of Shrine. Use `Attacher.default_url { ... }` instead.")
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
            shrine_class.opts[:default_url].call(context.merge(options){|k, old, new| old})
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
