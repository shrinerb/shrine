class Shrine
  module Plugins
    # The hooks plugin allows you to trigger some code before/after
    # uploading/processing/storing/deleting of each file.
    #
    #     plugin :hooks
    #
    # Shrine uses instance methods for hooks. To define a hook for an uploader,
    # you just add an instance method to the uploader:
    #
    #     class ImageUploader < Shrine
    #       def around_process(io, context)
    #         super
    #       rescue
    #         ExceptionNotifier.processing_failed(io, context)
    #       end
    #     end
    #
    # Each hook will be called with 2 arguments, `io` and `context`.  It's
    # generally good to always call super when overriding a hook, especially if
    # you're using inheritance with your uploaders.
    #
    # Shrine calls hooks in the following order when uploading a file:
    #
    # * `around_upload`
    #   * `before_upload`
    #   * `around_process`
    #     * `before_process`
    #     * PROCESS
    #     # `after_process`
    #   * `around_store`
    #     * `before_store`
    #     * STORE
    #     * `after_store`
    #   * `after_upload`
    #
    # Shrine calls hooks in the following order when deleting a file:
    #
    # * `around_delete`
    #   * `before_delete`
    #   * DELETE
    #   * `after_delete`
    #
    # It may be useful to know that you can realize some form of communication
    # between the hooks; whatever you save to the `context` hash will be
    # forwarded further down:
    #
    #     class ImageUploader < Shrine
    #       def before_upload(io, context)
    #         context[:_foo] = "bar"
    #         super
    #       end
    #
    #       def before_process(io, context)
    #         context[:_foo] #=> "bar"
    #         super
    #       end
    #     end
    #
    # Note that in that case you should always somehow mark this key as private
    # (for example with an underscore) so that it doesn't clash with any
    # existing keys.
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
