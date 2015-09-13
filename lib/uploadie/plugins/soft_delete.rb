class Uploadie
  module Plugins
    module SoftDelete
      module AttacherMethods
        def destroy
        end
      end
    end

    register_plugin(:soft_delete, SoftDelete)
  end
end
