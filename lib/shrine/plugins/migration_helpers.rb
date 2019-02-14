# frozen_string_literal: true

Shrine.deprecation("The migration_helpers plugin is deprecated and will be removed in Shrine 3. Attacher#cached? and Attacher#stored? have been moved to base.")

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/migration_helpers.md] on GitHub.
    #
    # [doc/plugins/migration_helpers.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/migration_helpers.md
    module MigrationHelpers
      def self.configure(uploader, delegate: false)
        uploader.opts[:migration_helpers_delegate] = delegate
      end

      module AttachmentMethods
        def initialize(name)
          super

          return if shrine_class.opts[:migration_helpers_delegate] == false

          name = attachment_name

          define_method :"update_#{name}" do |&block|
            send(:"#{name}_attacher").update_stored(&block)
          end

          define_method :"#{name}_cache" do
            send(:"#{name}_attacher").cache
          end

          define_method :"#{name}_store" do
            send(:"#{name}_attacher").store
          end

          define_method :"#{name}_cached?" do
            send(:"#{name}_attacher").cached?
          end

          define_method :"#{name}_stored?" do
            send(:"#{name}_attacher").stored?
          end
        end
      end

      module AttacherMethods
        # Updates the attachment with the result of the block. It will get
        # called only if the attachment exists and is stored.
        def update_stored(&block)
          return if get.nil? || cache.uploaded?(get)
          new_attachment = block.call(get)
          swap(new_attachment)
        end

        # Returns true if the attachment is present and is uploaded by the
        # temporary storage.
        def cached?
          get && cache.uploaded?(get)
        end

        # Returns true if the attachment is present and is uploaded by the
        # permanent storage.
        def stored?
          get && store.uploaded?(get)
        end
      end
    end

    register_plugin(:migration_helpers, MigrationHelpers)
  end
end
