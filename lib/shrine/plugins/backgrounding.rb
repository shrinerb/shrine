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
    #     attacher.promote_block do |attacher|
    #       Attachment::PromoteJob.perform_async(
    #         attacher.record,
    #         attacher.name,
    #         attacher.data,
    #       )
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
    #       def perform(record, name, data)
    #         attacher = Shrine::Attacher.retrieve(model: record, name: name, data: data)
    #         attacher.atomic_promote
    #       end
    #     end
    #
    # ## Deletion
    #
    #     attacher.destroy_block do |attacher|
    #       Attachment::DeleteJob.perform_async(attacher.data)
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
    #     class Attachment::DeleteJob
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
    #     Shrine::Attacher.promote_block do |attacher|
    #       Attachment::PromoteJob.perform_async(
    #         attacher.record,
    #         attacher.name,
    #         attacher.data,
    #       )
    #     end
    #
    #     Shrine::Attacher.destroy_block do |attacher|
    #       Attachment::PromoteJob.perform_async(attacher.data)
    #     end
    module Backgrounding
      module AttacherClassMethods
        # Registers a global promotion block.
        #
        #     Shrine::Attacher.promote_block do |attacher|
        #       Attachment::PromoteJob.perform_async(
        #         attacher.record,
        #         attacher.name,
        #         attacher.data,
        #       )
        #     end
        def promote_block(&block)
          @promote_block = block if block
          @promote_block
        end

        # Registers a global deletion block.
        #
        #     Shrine::Attacher.destroy_block do |attacher|
        #       Attachment::DeleteJob.perform_async(attacher.data)
        #     end
        def destroy_block(&block)
          @destroy_block = block if block
          @destroy_block
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
        #         attacher.data,
        #       )
        #     end
        def promote_block(&block)
          @promote_block = block if block
          @promote_block
        end

        # Registers an instance-level deletion hook.
        #
        #     attacher.destroy_block do |attacher|
        #       Attachment::DeleteJob.perform_async(attacher.data)
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
            promote_block.call(self, **options)
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
            destroy_block.call(self, **options)
          else
            super(**options)
          end
        end
      end
    end

    register_plugin(:backgrounding, Backgrounding)
  end
end
