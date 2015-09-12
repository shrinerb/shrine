class Uploadie
  module Plugins
    module DeleteCached
      module AttacherMethods
        def save
          cached = get
          super
          delete!(cached) if cached && cached?(cached)
        end
      end
    end

    register_plugin(:delete_cached, DeleteCached)
  end
end
