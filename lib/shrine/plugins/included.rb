class Shrine
  module Plugins
    # The included plugin allows you to hook up to the `.included` hook when
    # of the "attachment" module. This allows you to add additonal methods to
    # the model whenever an attachment is included.
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
    # The block is evaluated in the context of the model, but note that you
    # cannot use keywords like `def`, instead you should use the
    # metaprogramming equivalents like `define_method`. Now when an attachment
    # is included to a model, it will receive the appropriate methods:
    #
    #     class User
    #       include ImageUploader[:avatar]
    #     end
    #
    #     user = User.new
    #     user.avatar_width  #=> nil
    #     user.avatar_height #=> nil
    #
    #     user.avatar = File.open("avatar.jpg")
    #     user.avatar_width  #=> 300
    #     user.avatar_height #=> 500
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
