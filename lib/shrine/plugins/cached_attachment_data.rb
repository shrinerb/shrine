# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/cached_attachment_data.md] on GitHub.
    #
    # [doc/plugins/cached_attachment_data.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/cached_attachment_data.md
    module CachedAttachmentData
      module AttachmentMethods
        def initialize(*)
          super

          name = attachment_name

          define_method :"cached_#{name}_data" do
            send(:"#{name}_attacher").read_cached
          end
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
