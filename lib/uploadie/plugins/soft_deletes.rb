class Uploadie
  module Plugins
    module SoftDeletes
      module AttacherMethods
        def delete!(uploaded_file)
        end
      end
    end

    register_plugin(:soft_deletes, SoftDeletes)
  end
end
