require "active_record"

class Shrine
  module Plugins
    # The `activerecord` plugin extends the "attachment" interface with support
    # for ActiveRecord.
    #
    #     plugin :activerecord
    #
    # ## Callbacks
    #
    # Now the attachment module will add additional callbacks to the model:
    #
    # * `before_save` -- Used by the recache plugin.
    # * `after_commit on: [:create, :update]` -- Promotes the attachment, deletes replaced ones.
    # * `after_commit on: [:destroy]` -- Deletes the attachment.
    #
    # Note that ActiveRecord versions 3.x and 4.x have errors automatically
    # silenced in hooks, which can make debugging more difficult, so it's
    # recommended that you enable errors:
    #
    #     # This is the default in ActiveRecord 5
    #     ActiveRecord::Base.raise_in_transactional_callbacks = true
    #
    # Also note that if your tests are wrapped in transactions, the
    # `after_commit` callbacks won't get called, so in order to test uploading
    # you should first disable transactions for those tests.
    #
    # If you want to put promoting/deleting into a background job, see the
    # `backgrounding` plugin.
    #
    # Since attaching first saves the record with a cached attachment, then
    # saves again with a stored attachment, you can detect this in callbacks:
    #
    #     class User < ActiveRecord::Base
    #       include ImageUploader[:avatar]
    #
    #       before_save do
    #         if avatar_data_changed? && avatar_attacher.cached?
    #           # cached
    #         end
    #
    #         if avatar_data_changed? && avatar_attacher.stored?
    #           # promoted
    #         end
    #       end
    #     end
    #
    # If you don't want callbacks (e.g. you want to use the attacher object
    # directly), you can turn them off:
    #
    #     plugin :activerecord, callbacks: false
    #
    # ## Validations
    #
    # Additionally, any Shrine validation errors will be added to
    # ActiveRecord's errors upon validation. If you want to validate presence
    # of the attachment, you can do it directly on the model.
    #
    #     class User < ActiveRecord::Base
    #       include ImageUploader[:avatar]
    #       validates_presence_of :avatar
    #     end
    #
    # If you're doing validation separately from your models, you can turn off
    # validations for your models:
    #
    #     plugin :activerecord, validations: false
    module Activerecord
      def self.configure(uploader, opts = {})
        uploader.opts[:activerecord_callbacks] = opts.fetch(:callbacks, uploader.opts.fetch(:activerecord_callbacks, true))
        uploader.opts[:activerecord_validations] = opts.fetch(:validations, uploader.opts.fetch(:activerecord_validations, true))
      end

      module AttachmentMethods
        def included(model)
          super

          return unless model < ::ActiveRecord::Base

          opts = shrine_class.opts

          model.class_eval <<-RUBY, __FILE__, __LINE__ + 1 if opts[:activerecord_validations]
            validate do
              #{@name}_attacher.errors.each do |message|
                errors.add(:#{@name}, message)
              end
            end
          RUBY

          model.class_eval <<-RUBY, __FILE__, __LINE__ + 1 if opts[:activerecord_callbacks]
            before_save do
              #{@name}_attacher.save if #{@name}_attacher.attached?
            end

            after_commit on: [:create, :update] do
              #{@name}_attacher.finalize if #{@name}_attacher.attached?
            end

            after_commit on: [:destroy] do
              #{@name}_attacher.destroy
            end
          RUBY
        end
      end

      module AttacherClassMethods
        # Needed by the `backgrounding` plugin.
        def find_record(record_class, record_id)
          record_class.where(id: record_id).first
        end
      end

      module AttacherMethods
        private

        # Saves the record after assignment, skipping validations.
        def update(uploaded_file)
          super
          record.save(validate: false)
        end
      end
    end

    register_plugin(:activerecord, Activerecord)
  end
end
