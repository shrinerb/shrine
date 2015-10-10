class Shrine
  module Plugins
    module Recache
      module AttacherMethods
        def save
          if get && defined?(@old_attachment) # new file was assigned
            _set cache!(get, phase: :recache)
          end
          super
        end
      end
    end

    register_plugin(:recache, Recache)
  end
end
