# frozen_string_literal: true

class Shrine
  module Plugins
    # The `delete_promoted` plugin deletes files that have been promoted, after
    # the record is saved. This means that cached files handled by the attacher
    # will automatically get deleted once they're uploaded to store. This also
    # applies to any other uploaded file passed to `Attacher#promote`.
    #
    #     plugin :delete_promoted
    module DeletePromoted
      module AttacherMethods
        def promote(uploaded_file = get, **options)
          result = super
          _delete(uploaded_file, action: :promote)
          result
        end
      end
    end

    register_plugin(:delete_promoted, DeletePromoted)
  end
end
