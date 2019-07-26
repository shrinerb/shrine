# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/cached_attachment_data.md] on GitHub.
    #
    # [doc/plugins/cached_attachment_data.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/cached_attachment_data.md
    module CachedAttachmentData
      module AttachmentMethods
        def included(klass)
          super

          return unless options[:type] == :model

          name = attachment_name

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
