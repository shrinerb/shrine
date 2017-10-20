# frozen_string_literal: true

class Shrine
  module Plugins
    # The `hooks` plugin allows you to trigger some code around
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
    # * `before_upload`
    # * `around_upload`
    #     * `before_process`
    #     * `around_process`
    #     * `after_process`
    #     * `before_store`
    #     * `around_store`
    #     * `after_store`
    # * `after_upload`
    #
    # Shrine calls hooks in the following order when deleting a file:
    #
    # * `before_delete`
    # * `around_delete`
    # * `after_delete`
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
