require "sequel"

class Shrine
  module Plugins
    # The sequel plugin extends the "attachment" interface with support for
    # Sequel.
    #
    #     plugin :sequel
    #
    # ## Callbacks
    #
    # Now the attachment module will add additional callbacks to the model:
    #
    # * `before_save` -- Used by the recached plugin.
    # * `after_commit` -- Promotes the attachment, deletes replaced ones.
    # * `after_destroy_commit` -- Deletes the attachment.
    #
    # Also note that if your tests are wrapped in transactions, the
    # `after_commit` callbacks won't get called, so in order to test uploading
    # you should first disable transactions for those tests.
    #
    # If you want to put promoting/deleting into a background job, see the
    # backgrounding plugin.
    #
    # Since attaching first saves the record with a cached attachment, then
    # saves again with a stored attachment, you can detect this in callbacks:
    #
    #     class User < Sequel::Model
    #       include ImageUploader[:avatar]
    #
    #       def before_save
    #         super
    #
    #         if changed_columns.include?(:avatar) && avatar_attacher.cached?
    #           # cached
    #         end
    #
    #         if changed_columns.include?(:avatar) && avatar_attacher.stored?
    #           # promoted
    #         end
    #       end
    #     end
    #
    # If you don't want callbacks (e.g. you want to use the attacher object
    # directly), you can turn them off:
    #
    #     plugin :sequel, callbacks: false
    #
    # ## Validations
    #
    # Additionally, any Shrine validation errors will added to Sequel's
    # errors upon validation. Note that if you want to validate presence of the
    # attachment, you can do it directly on the model.
    #
    #     class User < Sequel::Model
    #       include ImageUploader[:avatar]
    #       validates_presence_of :avatar
    #     end
    #
    # If you're doing validation separately from your models, you can turn off
    # validations for your models:
    #
    #     plugin :sequel, validations: false
    module Sequel
      def self.configure(uploader, opts = {})
        uploader.opts[:sequel_callbacks] = opts.fetch(:callbacks, uploader.opts.fetch(:sequel_callbacks, true))
        uploader.opts[:sequel_validations] = opts.fetch(:validations, uploader.opts.fetch(:sequel_validations, true))
      end

      module AttachmentMethods
        def included(model)
          super

          return unless model < ::Sequel::Model

          opts = shrine_class.opts

          module_eval <<-RUBY, __FILE__, __LINE__ + 1 if opts[:sequel_validations]
            def validate
              super
              #{@name}_attacher.errors.each do |message|
                errors.add(:#{@name}, message)
              end
            end
          RUBY

          module_eval <<-RUBY, __FILE__, __LINE__ + 1 if opts[:sequel_callbacks]
            def before_save
              super
              #{@name}_attacher.save if #{@name}_attacher.attached?
            end

            def after_commit
              super
              #{@name}_attacher.finalize if #{@name}_attacher.attached?
            end

            def after_destroy_commit
              super
              #{@name}_attacher.destroy
            end
          RUBY
        end
      end

      module AttacherClassMethods
        # Needed by the backgrounding plugin.
        def find_record(record_class, record_id)
          record_class.with_pk(record_id)
        end
      end

      module AttacherMethods
        private

        # Saves the record after assignment, skipping validations.
        def update(uploaded_file)
          super
          record.save(validate: false)
        end

        # Support for Postgres JSON columns.
        def read
          value = super
          value = value.to_hash if value.respond_to?(:to_hash)
          value
        end
      end
    end

    register_plugin(:sequel, Sequel)
  end
end
