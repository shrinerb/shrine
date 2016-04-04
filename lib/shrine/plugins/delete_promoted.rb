class Shrine
  module Plugins
    module DeletePromoted
      module AttacherMethods
        def promote(uploaded_file, *)
          result = super
          delete!(uploaded_file, phase: :promote)
          result
        end
      end
    end

    register_plugin(:delete_promoted, DeletePromoted)
  end
end
