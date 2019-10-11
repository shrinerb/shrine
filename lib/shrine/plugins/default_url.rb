# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/default_url
    module DefaultUrl
      def self.configure(uploader, **opts)
        uploader.opts[:default_url] ||= {}
        uploader.opts[:default_url].merge!(opts)
      end

      module AttacherClassMethods
        def default_url(&block)
          shrine_class.opts[:default_url][:block] = block
        end
      end

      module AttacherMethods
        def url(**options)
          super || default_url(**options)
        end

        private

        def default_url(**options)
          return unless default_url_block

          url = instance_exec(options, &default_url_block)

          [*default_url_host, url].join
        end

        def default_url_block
          shrine_class.opts[:default_url][:block]
        end

        def default_url_host
          shrine_class.opts[:default_url][:host]
        end
      end
    end

    register_plugin(:default_url, DefaultUrl)
  end
end
