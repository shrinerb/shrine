# frozen_string_literal: true

Shrine.deprecation("The recache plugin is deprecated and will be removed in Shrine 4. If you were using it with versions plugin, use the new derivatives plugin instead.")

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/recache
    module Recache
      module AttacherMethods
        def save
          recache
          super
        end

        def recache
          if cached?
            result = upload(file, cache_key, action: :recache)

            set(result)
          end
        end
      end
    end

    register_plugin(:recache, Recache)
  end
end
