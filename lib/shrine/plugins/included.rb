class Shrine
  module Plugins
    # The included plugin allows you to hook up to the `.included` hook of the
    # attachment module, and do additional action on the model which includes
    # it.
    #
    #     plugin :included do |name|
    #       define_method("#{name}_width") do
    #         send(name).width if send(name)
    #       end
    #
    #       define_method("#{name}_height") do
    #         send(name).height if send(name)
    #       end
    #     end
    #
    # The block is evaluated in the context of the model via `instance_exec`.
    # This means you cannot use keywords like `def`, instead you should use the
    # metaprogramming equivalents like `define_method`.
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
