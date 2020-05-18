# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/remove_attachment
    module RemoveAttachment
      module AttachmentMethods
        def define_model_methods(name)
          super if defined?(super)

          define_method :"remove_#{name}=" do |value|
            send(:"#{name}_attacher").remove = value
          end

          define_method :"remove_#{name}" do
            send(:"#{name}_attacher").remove
          end
        end
      end

      module AttacherMethods
        # We remove the attachment if the value evaluates to true.
        def remove=(value)
          @remove = value

          change(nil) if remove?
        end

        def remove
          @remove
        end

        private

        # Don't override previously removed attachment that wasn't yet deleted.
        def change?(file)
          super && !(changed? && remove?)
        end

        # Rails sends "0" or "false" if the checkbox hasn't been ticked.
        def remove?
          remove && remove != "" && remove !~ /\A(0|false)\z/
        end
      end
    end

    register_plugin(:remove_attachment, RemoveAttachment)
  end
end
