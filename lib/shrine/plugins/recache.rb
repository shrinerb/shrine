class Shrine
  module Plugins
    # The recache plugin allows you to process your attachment after
    # validations succeed, but before the attachment is promoted. This is
    # useful for example when you want to generate some versions upfront (so
    # the user immediately sees them) and other versions you want to generate
    # in the promotion phase in a background job.
    #
    #     plugin :recache
    #     plugin :processing
    #
    #     process(:recache) do |io, context|
    #       # perform cheap processing
    #     end
    #
    #     process(:store) do |io, context|
    #       # perform more expensive processing
    #     end
    module Recache
      module AttacherMethods
        def save
          if cached?
            recached = cache!(get, action: :recache)
            _set(recached)
          end
          super
        end
      end
    end

    register_plugin(:recache, Recache)
  end
end
