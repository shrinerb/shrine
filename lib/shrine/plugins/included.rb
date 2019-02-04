# frozen_string_literal: true

class Shrine
  module Plugins
    module Included
      def self.configure(uploader, &block)
        uploader.opts[:included_block] = block
      end

      module AttachmentMethods
        def included(model)
          super
          model.instance_exec(@name, &shrine_class.opts[:included_block])
        end
      end
    end

    register_plugin(:included, Included)
  end
end
