# frozen_string_literal: true

class Shrine
  module Plugins
    # The `remove_invalid` plugin automatically deletes a new assigned file if
    # it was invalid and deassigns it from the record. If there was a previous
    # file attached, it will be assigned back, otherwise no attachment will be
    # assigned.
    #
    #     plugin :remove_invalid
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
