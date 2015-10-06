class Shrine
  module Plugins
    module Hooks
      module InstanceMethods
        def upload(io, context = {})
          result = nil
          around_upload(io, context) { result = super }
          result
        end

        def around_upload(*args)
          before_upload(*args)
          yield
          after_upload(*args)
        end

        def before_upload(*)
        end

        def after_upload(*)
        end


        def processed(io, context)
          result = nil
          around_process(io, context) { result = super }
          result
        end
        private :processed

        def around_process(*args)
          before_process(*args)
          yield
          after_process(*args)
        end

        def before_process(*)
        end

        def after_process(*)
        end


        def store(io, context = {})
          result = nil
          around_store(io, context) { result = super }
          result
        end

        def around_store(*args)
          before_store(*args)
          yield
          after_store(*args)
        end

        def before_store(*)
        end

        def after_store(*)
        end


        def delete(io, context = {})
          result = nil
          around_delete(io, context) { result = super }
          result
        end

        def around_delete(*args)
          before_delete(*args)
          yield
          after_delete(*args)
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
