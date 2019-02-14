# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/hooks.md] on GitHub.
    #
    # [doc/plugins/hooks.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/hooks.md
    module Hooks
      module InstanceMethods
        def upload(io, context = {})
          result = nil
          before_upload(io, context)
          around_upload(io, context) { result = super }
          after_upload(io, context)
          result
        end

        def around_upload(*args)
          yield
        end

        def before_upload(*)
        end

        def after_upload(*)
        end


        def processed(io, context)
          result = nil
          before_process(io, context)
          around_process(io, context) { result = super }
          after_process(io, context)
          result
        end
        private :processed

        def around_process(*args)
          yield
        end

        def before_process(*)
        end

        def after_process(*)
        end


        def store(io, context = {})
          result = nil
          before_store(io, context)
          around_store(io, context) { result = super }
          after_store(io, context)
          result
        end

        def around_store(*args)
          yield
        end

        def before_store(*)
        end

        def after_store(*)
        end


        def delete(io, context = {})
          result = nil
          before_delete(io, context)
          around_delete(io, context) { result = super }
          after_delete(io, context)
          result
        end

        def around_delete(*args)
          yield
        end

        def before_delete(*)
        end

        def after_delete(*)
        end
      end
    end

    register_plugin(:hooks, Hooks)
  end
end
