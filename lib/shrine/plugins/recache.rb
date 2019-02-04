# frozen_string_literal: true

class Shrine
  module Plugins
    module Recache
      module AttacherMethods
        def save
          recache
          super
        end

        def recache
          if cached?
            recached = cache!(get, action: :recache)
            _set(recached)
          end
        end
      end
    end

    register_plugin(:recache, Recache)
  end
end
