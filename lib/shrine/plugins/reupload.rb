class Shrine
  module Plugins
    module Reupload
      module AttacherMethods
        def save
          if get && defined?(@old_attachment) # new file was assigned
            if cache.uploaded?(get)
              _set cache!(get, phase: :reupload)
            else
              _set store!(get, phase: :reupload)
            end
          end
          super
        end
      end
    end

    register_plugin(:reupload, Reupload)
  end
end
