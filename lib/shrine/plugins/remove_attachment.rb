class Shrine
  module Plugins
    # The remove_attachment plugin allows you to delete attachments through
    # checkboxes on the web form.
    #
    #     plugin :remove_attachment
    #
    # If for example your attachment is called "avatar", this plugin will add
    # `#remove_avatar` and `#remove_avatar=` methods to your model. This allows
    # you to easily enable deleting attached files through the form:
    #
    #     <%= form_for @user do |f| %>
    #       <%= f.hidden_field :avatar, value: @user.avatar_data %>
    #       <%= f.file_field :avatar %>
    #       Remove attachment: <%= f.check_box :remove_avatar %>
    #     <% end %>
    #
    # Now when the checkbox is ticked and the form is submitted, the attached
    # file will be removed.
    module RemoveAttachment
      module AttachmentMethods
        def initialize(name, *args)
          super

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def remove_#{name}=(value)
              #{name}_attacher.remove = value
            end

            def remove_#{name}
              #{name}_attacher.remove
            end
          RUBY
        end
      end

      module AttacherMethods
        # We remove the attachment if the value evaluates to true.
        def remove=(value)
          @remove = value
          set(nil) if remove?
        end

        def remove
          @remove
        end

        private

        # Rails sends "0" or "false" if the checkbox hasn't been ticked.
        def remove?
          remove && remove != "" && remove !~ /\A0|false$\z/
        end
      end
    end

    register_plugin(:remove_attachment, RemoveAttachment)
  end
end
