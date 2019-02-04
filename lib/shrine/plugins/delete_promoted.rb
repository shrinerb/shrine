# frozen_string_literal: true

class Shrine
  module Plugins
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
