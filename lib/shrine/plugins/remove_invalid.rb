class Shrine
  module Plugins
    # The `remove_invalid` plugin automatically deletes a cached file if it was
    # invalid and deassigns it from the record. If there was a previous file
    # attached, it will be assigned back, otherwise `nil` will be assigned.
    #
    #     plugin :remove_invalid
    module RemoveInvalid
      module AttacherMethods
        def validate
          super
        ensure
          if errors.any? && cached?
            _delete(get, action: :validate)
            _set(@old)
          end
        end
      end
    end

    register_plugin(:remove_invalid, RemoveInvalid)
  end
end
