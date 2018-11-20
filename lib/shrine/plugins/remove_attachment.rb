# frozen_string_literal: true

class Shrine
  module Plugins
    # The `remove_attachment` plugin allows you to delete attachments through
    # checkboxes on the web form.
    #
    #     plugin :remove_attachment
    #
    # If for example your attachment is called "avatar", this plugin will add
    # `#remove_avatar` and `#remove_avatar=` methods to your model. This allows
    # you to add a form field for removing attachments:
    #
    #     form.check_box :remove_avatar
    module RemoveAttachment
      module AttachmentMethods
        def initialize(*)
          super

          name = attachment_name

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
          assign(nil) if remove?
        end

        def remove
          @remove
        end

        private

        # Rails sends "0" or "false" if the checkbox hasn't been ticked.
        def remove?
          remove && remove != "" && remove !~ /\A(0|false)\z/
        end
      end
    end

    register_plugin(:remove_attachment, RemoveAttachment)
  end
end
