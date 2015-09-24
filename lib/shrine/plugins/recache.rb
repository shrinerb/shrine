class Shrine
  module Plugins
    module Recache
      module AttacherMethods
        def save
          super
          if get && defined?(@old_attachment) # new file was assigned
            if cache.uploaded?(get)
              _set cache!(get, phase: :recache)
            else
              _set store!(get, phase: :recache)
            end
          end
        end
      end
    end

    register_plugin(:recache, Recache)
  end
end
