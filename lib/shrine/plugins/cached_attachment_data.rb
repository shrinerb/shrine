# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/cached_attachment_data
    module CachedAttachmentData
      module AttachmentMethods
        def define_model_methods(name)
          super if defined?(super)

          define_method :"cached_#{name}_data" do
            send(:"#{name}_attacher").cached_data
          end
        end
      end

      module AttacherMethods
        def cached_data
          file.to_json if cached? && changed?
        end
      end
    end

    register_plugin(:cached_attachment_data, CachedAttachmentData)
  end
end
