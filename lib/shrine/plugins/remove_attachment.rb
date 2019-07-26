# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/remove_attachment.md] on GitHub.
    #
    # [doc/plugins/remove_attachment.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/remove_attachment.md
    module RemoveAttachment
      module AttachmentMethods
        def included(klass)
          super

          return unless options[:type] == :model

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

          change(nil) if remove?
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
