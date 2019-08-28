# frozen_string_literal: true

class Shrine
  module Plugins
    # The backgrounding plugin allows delaying promotion and deletion into a
    # background job.
    #
    # You can register promotion and deletion blocks on an instance of the
    # attacher, and they will be called as needed.
    #
    # ## Promotion
    #
    #     attacher.promote_block do
    #       Attachment::PromoteJob.perform_async(record, name, file_data)
    #     end
    #
    #     attacher.assign(io)
    #     attacher.finalize # promote block called
    #
    #     attacher.file # cached file
    #     # ... background job finishes ...
    #     attacher.file # stored file
    #
    # The promote worker can be implemented like this:
    #
    #     class Attachment::PromoteJob
    #       def perform(record, name, file_data)
    #         attacher = Shrine::Attacher.retrieve(model: record, name: name, file: file_data)
    #         attacher.atomic_promote
    #       end
    #     end
    #
    # ## Deletion
    #
    #     attacher.destroy_block do
    #       Attachment::DestroyJob.perform_async(data)
    #     end
    #
    #     previous_file = attacher.file
    #
    #     attacher.attach(io)
    #     attacher.finalize # delete hook called
    #
    #     previous_file.exists? #=> true
    #     # ... background job finishes ...
    #     previous_file.exists? #=> false
    #
    #     attacher.destroy_attached
    #
    #     attacher.file.exists? #=> true
    #     # ... background job finishes ...
    #     attacher.file.exists? #=> false
    #
    # The delete worker can be implemented like this:
    #
    #     class Attachment::DestroyJob
    #       def perform(data)
    #         attacher = Shrine::Attacher.from_data(data)
    #         attacher.destroy
    #       end
    #     end
    #
    # ## Global hooks
    #
    # You can also register promotion and deletion hooks globally:
    #
    #     Shrine::Attacher.promote_block do
    #       Attachment::PromoteJob.perform_async(record, name, file_data)
    #     end
    #
    #     Shrine::Attacher.destroy_block do
    #       Attachment::DestroyJob.perform_async(data)
    #     end
    module Backgrounding
      def self.configure(uploader)
        uploader.opts[:backgrounding] ||= {}
      end

      module AttacherClassMethods
        # Registers a global promotion block.
        #
        #     Shrine::Attacher.promote_block do |attacher|
        #       Attachment::PromoteJob.perform_async(
        #         attacher.record,
        #         attacher.name,
        #         attacher.file_data,
        #       )
        #     end
        def promote_block(&block)
          shrine_class.opts[:backgrounding][:promote_block] = block if block
          shrine_class.opts[:backgrounding][:promote_block]
        end

        # Registers a global deletion block.
        #
        #     Shrine::Attacher.destroy_block do |attacher|
        #       Attachment::DestroyJob.perform_async(attacher.data)
        #     end
        def destroy_block(&block)
          shrine_class.opts[:backgrounding][:destroy_block] = block if block
          shrine_class.opts[:backgrounding][:destroy_block]
        end
      end

      module AttacherMethods
        # Inherits global hooks if defined.
        def initialize(*args)
          super
          @destroy_block = self.class.destroy_block
          @promote_block = self.class.promote_block
        end

        # Registers an instance-level promotion hook.
        #
        #     attacher.promote_block do |attacher|
        #       Attachment::PromoteJob.perform_async(
        #         attacher.record,
        #         attacher.name
        #         attacher.file_data,
        #       )
        #     end
        def promote_block(&block)
          @promote_block = block if block
          @promote_block
        end

        # Registers an instance-level deletion hook.
        #
        #     attacher.destroy_block do |attacher|
        #       Attachment::DestroyJob.perform_async(attacher.data)
        #     end
        def destroy_block(&block)
          @destroy_block = block if block
          @destroy_block
        end

        # Signals the #promote method that it should use backgrounding if
        # registered.
        def promote_cached(**options)
          super(background: true, **options)
        end

        # Calls the promotion hook if registered and called via #promote_cached,
        # otherwise promotes synchronously.
        def promote(background: false, **options)
          if promote_block && background
            background_block(promote_block, **options)
          else
            super(**options)
          end
        end

        # Signals the #destroy method that it should use backgrounding if
        # registered.
        def destroy_attached(**options)
          super(background: true, **options)
        end

        # Calls the destroy hook if registered and called via #destroy_attached,
        # otherwise destroys synchronously.
        def destroy(background: false, **options)
          if destroy_block && background
            background_block(destroy_block, **options)
          else
            super(**options)
          end
        end

        private

        def background_block(block, **options)
          if block.arity == 1
            block.call(self, **options)
          else
            instance_exec(**options, &block)
          end
        end
      end
    end

    register_plugin(:backgrounding, Backgrounding)
  end
end
