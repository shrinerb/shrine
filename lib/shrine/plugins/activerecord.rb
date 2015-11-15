require "active_record"

class Shrine
  module Plugins
    # The activerecord plugin extends the "attachment" interface with support
    # for ActiveRecord.
    #
    #     plugin :activerecord
    #
    # Now whenever an "attachment" module is included, additional callbacks are
    # added to the model:
    #
    # * `before_save` -- Currently only used by the recache plugin.
    # * `after_commit on: [:create, :update]` -- Promotes the attachment, deletes replaced ones.
    # * `after_commit on: [:destroy]` -- Deletes the attachment.
    #
    # Note that if your tests are wrapped in transactions, the `after_commit`
    # callbacks won't get called, so in order to test uploading you should first
    # disable these transactions for those tests.
    #
    # If you want to put some parts of this lifecycle into a background job, see
    # the background_helpers plugin.
    #
    # Additionally, any Shrine validation errors will added to ActiveRecord's
    # errors upon validation. Note that if you want to validate presence of the
    # attachment, you can do it directly on the model.
    #
    #     class User < ActiveRecord::Base
    #       include ImageUploader[:avatar]
    #       validates_presence_of :avatar
    #     end
    module Activerecord
      module AttachmentMethods
        def included(model)
          super

          model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            validate do
              #{@name}_attacher.errors.each do |message|
                errors.add(:#{@name}, message)
              end
            end

            before_save do
              #{@name}_attacher.save if #{@name}_attacher.attached?
            end

            after_commit on: [:create, :update] do
              #{@name}_attacher.finalize if #{@name}_attacher.attached?
            end

            after_commit on: :destroy do
              #{@name}_attacher.destroy
            end
          RUBY
        end
      end

      module AttacherClassMethods
        # Needed by the background_helpers plugin.
        def find_record(record_class, record_id)
          record_class.find(record_id)
        end
      end

      module AttacherMethods
        private

        # We save the record after updating, raising any validation errors.
        def update(uploaded_file)
          super
          record.save!
        end

        # If we're in a transaction, then promoting is happening inline. If
        # we're not, then this is happening in a background job. In that case
        # when we're checking that the attachment changed during storing, we
        # need to first reload the record to pick up new columns.
        def changed?(uploaded_file)
          record.reload
          super
        end
      end
    end

    register_plugin(:activerecord, Activerecord)
  end
end
