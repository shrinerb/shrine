class Shrine
  module Plugins
    # The cached_attachment_data adds a method for assigning cached files that
    # is more convenient for forms.
    #
    #     plugin :cached_attachment_data
    #
    # If for example your attachment is called "avatar", this plugin will add
    # `#cached_avatar_data` and `#cached_avatar_data=` methods to your model.
    # This allows you to write your hidden field without explicitly setting
    # `:value`:
    #
    #     <%= form_for @user do |f| %>
    #       <%= f.hidden_field :cached_avatar_data %>
    #       <%= f.field_field :avatar %>
    #     <% end %>
    #
    # Additionally, the hidden field will only be set when the attachment is
    # cached (as opposed to the default where `user.avatar_data` will return
    # both cached and stored files). This keeps Rails logs cleaner.
    module CachedAttachmentData
      module AttachmentMethods
        def initialize(name)
          super

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def cached_#{name}_data
              #{name}_attacher.read_cached
            end

            def cached_#{name}_data=(value)
              #{name}_attacher.assign(value)
            end
          RUBY
        end
      end

      module AttacherMethods
        def read_cached
          get.to_json if get && cache.uploaded?(get)
        end
      end
    end

    register_plugin(:cached_attachment_data, CachedAttachmentData)
  end
end
