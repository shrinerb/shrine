class Uploadie
  module Plugins
    module DeleteCached
      module AttacherMethods
        def save
          uploaded_file = get
          super
          delete!(uploaded_file) if uploaded_file && cache.uploaded?(uploaded_file)
        end
      end
    end

    register_plugin(:delete_cached, DeleteCached)
  end
end
