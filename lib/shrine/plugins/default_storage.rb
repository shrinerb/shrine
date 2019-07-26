# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/default_storage.md] on GitHub.
    #
    # [doc/plugins/default_storage.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/default_storage.md
    module DefaultStorage
      def self.configure(uploader, **opts)
        uploader.opts[:default_storage] ||= {}
        uploader.opts[:default_storage].merge!(opts)
      end

      module AttacherMethods
        def initialize(**options)
          super(**shrine_class.opts[:default_storage], **options)
        end
      end
    end

    register_plugin(:default_storage, DefaultStorage)
  end
end
