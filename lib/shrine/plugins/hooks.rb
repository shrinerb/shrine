class Shrine
  module Plugins
    # The hooks plugin allows you to trigger some code around
    # processing/storing/deleting of each file.
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
    # Each hook will be called with 2 arguments, `io` and `context`. You should
    # always call `super` when overriding a hook, as other plugins may be using
    # hooks internally, and without `super` those wouldn't get executed.
    #
    # Shrine calls hooks in the following order when uploading a file:
    #
    # * `around_upload`
    #     * `before_upload`
    #     * `around_process`
    #         * `before_process`
    #         * PROCESS
    #         * `after_process`
    #     * `around_store`
    #         * `before_store`
    #         * STORE
    #         * `after_store`
    #     * `after_upload`
    #
    # Shrine calls hooks in the following order when deleting a file:
    #
    # * `around_delete`
    #     * `before_delete`
    #     * DELETE
    #     * `after_delete`
    #
    # By default every `around_*` hook returns the result of the corresponding
    # operation:
    #
    #     class ImageUploader < Shrine
    #       def around_store(io, context)
    #         result = super
    #         result.class #=> Shrine::UploadedFile
    #         result # it's good to always return the result for consistent behaviour
    #       end
    #     end
    #
    # It may be useful to know that you can realize some form of communication
    # between the hooks; whatever you save to the `context` hash will be
    # forwarded further down:
    #
    #     class ImageUploader < Shrine
    #       def before_process(io, context)
    #         context[:_foo] = "bar"
    #         super
    #       end
    #
    #       def before_store(io, context)
    #         context[:_foo] #=> "bar"
    #         super
    #       end
    #     end
    #
    # In that case you should always somehow mark this key as private (for
    # example with an underscore) so that it doesn't clash with any
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
          result = yield
          after_upload(*args)
          result
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
          result = yield
          after_process(*args)
          result
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
          result = yield
          after_store(*args)
          result
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
          result = yield
          after_delete(*args)
        end

        def before_delete(*)
        end

        def after_delete(*)
        end


        def around_promote(*args)
          before_promote(*args)
          result = yield
          after_promote(*args)
        end

        def before_promote(*)
        end

        def after_promote(*)
        end
      end

      module AttacherMethods
        def promote(cached_file)
          result = nil
          store.around_promote(cached_file, record: record) { result = super }
          result
        end
      end
    end

    register_plugin(:hooks, Hooks)
  end
end
