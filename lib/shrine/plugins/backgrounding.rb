# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/backgrounding
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
        def initialize(**args)
          super(**args)
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

        # Does a background promote if promote block was registered.
        def promote_cached(**options)
          if promote? && promote_block
            promote_background
          else
            super
          end
        end

        # Calls the registered promote block.
        def promote_background(**options)
          fail Error, "promote block is not registered" unless promote_block

          background_block(promote_block, **options)
        end

        # Does a background destroy if destroy block was registered.
        def destroy_attached
          if destroy? && destroy_block
            destroy_background
          else
            super
          end
        end

        # Calls the registered destroy block.
        def destroy_background(**options)
          fail Error, "destroy block is not registered" unless destroy_block

          background_block(destroy_block, **options)
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
