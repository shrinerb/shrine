class Shrine
  module Plugins
    # The included plugin allows you to hook up to the `.included` hook of the
    # attachment module, and call additional methods on the model which includes
    # it.
    #
    #     plugin :included do |name|
    #       before_save do
    #         # ...
    #       end
    #     end
    #
    # If you want to define additional methods on the model, it's recommended
    # to use the module_include plugin instead.
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
