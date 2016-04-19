class Shrine
  module Plugins
    # The remove_invalid plugin automatically deletes a cached file if it was
    # invalid and deassigns it from the record.
    #
    #     plugin :remove_invalid
    module RemoveInvalid
      module AttacherMethods
        def validate
          super
        ensure
          if errors.any? && cache.uploaded?(get)
            delete!(get, phase: :validate)
            _set(nil)
          end
        end
      end
    end

    register_plugin(:remove_invalid, RemoveInvalid)
  end
end
