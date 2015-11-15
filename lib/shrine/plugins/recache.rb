class Shrine
  module Plugins
    # The recache plugin allows you to process your attachment after
    # validations succeed, but before the attachment is promoted. This is
    # useful for example when you want to generate some versions upfront (so
    # the user immediately sees them) and other versions you want to generate
    # in the promotion phase in a background job.
    #
    # The phase will be set to `:recache`:
    #
    #     class ImageUploader
    #       plugin :recache
    #
    #       def process(io, context)
    #         case context[:phase]
    #         when :recache
    #           # generate cheap versions
    #         when :store
    #           # generate more expensive versions
    #         end
    #       end
    #     end
    module Recache
      module AttacherMethods
        def save
          if get && cache.uploaded?(get)
            _set cache!(get, phase: :recache)
          end
          super
        end
      end
    end

    register_plugin(:recache, Recache)
  end
end
