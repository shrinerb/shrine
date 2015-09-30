class Shrine
  module Plugins
    module DeleteInvalid
      module AttacherMethods
        def validate
          super
        ensure
          delete!(get, phase: :invalid) if !errors.empty?
        end
      end
    end

    register_plugin(:delete_invalid, DeleteInvalid)
  end
end
