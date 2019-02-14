# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/delete_promoted.md] on GitHub.
    #
    # [doc/plugins/delete_promoted.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/delete_promoted.md
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
