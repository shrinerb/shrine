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
    # * `before_save` -- Promotes the attachment from `:cache` to `:store`.
    # * `after_save` -- Deletes a replaced attachment.
    # * `after_destroy` -- Deletes the attachment.
    #
    # If you want to put some parts of this lifecycle in a background job, see
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
              #{@name}_attacher.save
            end

            after_save do
              #{@name}_attacher.replace
            end

            after_destroy do
              #{@name}_attacher.destroy
            end
          RUBY
        end
      end

      module AttacherMethods
        private

        # If we're in a transaction, then promoting is happening inline. If
        # we're not, then this is happening in a background job. In that case
        # when we're checking that the attachment changed during storing, we
        # need to first reload the record to pick up new columns.
        def changed?(uploaded_file)
          record.reload unless in_transaction?
          super
        end

        # Returns true if we are currently inside a transaction.
        def in_transaction?
          record.class.connection.transaction_open?
        end
      end
    end

    register_plugin(:activerecord, Activerecord)
  end
end
