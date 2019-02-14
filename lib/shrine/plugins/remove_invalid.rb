# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/remove_invalid.md] on GitHub.
    #
    # [doc/plugins/remove_invalid.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/remove_invalid.md
    module RemoveInvalid
      module AttacherMethods
        def validate
          super
        ensure
          if errors.any? && changed?
            _delete(get, action: :validate)
            _set(@old)
            remove_instance_variable(:@old)
          end
        end
      end
    end

    register_plugin(:remove_invalid, RemoveInvalid)
  end
end
