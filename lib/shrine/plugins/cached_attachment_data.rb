# frozen_string_literal: true

class Shrine
  module Plugins
    # The `cached_attachment_data` plugin adds the ability to retain the cached
    # file across form redisplays, which means the file doesn't have to be
    # reuploaded in case of validation errors.
    #
    #     plugin :cached_attachment_data
    #
    # The plugin adds `#cached_<attachment>_data` to the model, which returns
    # the cached file as JSON, and should be used to set the value of the
    # hidden form field.
    #
    #     @user.cached_avatar_data #=> '{"id":"38k25.jpg","storage":"cache","metadata":{...}}'
    #
    # This method delegates to `Attacher#read_cached`:
    #
    #     attacher.read_cached #=> '{"id":"38k25.jpg","storage":"cache","metadata":{...}}'
    module CachedAttachmentData
      module AttachmentMethods
        def initialize(*)
          super

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def cached_#{@name}_data
              #{@name}_attacher.read_cached
            end

            def cached_#{@name}_data=(value)
              Shrine.deprecation("Calling #cached_#{@name}_data= is deprecated and will be removed in Shrine 3. You should use the original field name: `f.hidden_field :#{@name}, value: record.cached_#{@name}_data`.")
              #{@name}_attacher.assign(value)
            end
          RUBY
        end
      end

      module AttacherMethods
        def read_cached
          get.to_json if cached? && changed?
        end
      end
    end

    register_plugin(:cached_attachment_data, CachedAttachmentData)
  end
end
