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
    # Note that ActiveRecord versions 3.x and 4.x have errors automatically
    # silenced in hooks, which can make debugging more difficult, so it's
    # recommended that you enable errors:
    #
    #     # This is the default in ActiveRecord 5
    #     ActiveRecord::Base.raise_in_transactional_callbacks = true
    #
    # Also note that if your tests are wrapped in transactions, the
    # `after_commit` callbacks won't get called, so in order to test uploading
    # you should first disable these transactions for those tests.
    #
    # If you want to put some parts of this lifecycle into a background job, see
    # the backgrounding plugin.
    #
    # Additionally, any Shrine validation errors will be added to
    # ActiveRecord's errors upon validation. If you want to validate presence
    # of the attachment, you can do it directly on the model.
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
        # Needed by the backgrounding plugin.
        def find_record(record_class, record_id)
          record_class.where(id: record_id).first
        end
      end

      module AttacherMethods
        private

        # Updates the current attachment with the new one, unless the current
        # attachment has changed.
        def update(uploaded_file)
          record.class.where(record.class.primary_key => record.id)
            .where(:"#{name}_data" => record.send(:"#{name}_data"))
            .update_all(:"#{name}_data" => uploaded_file.to_json)
          record.reload
        rescue ::ActiveRecord::RecordNotFound
        end
      end
    end

    register_plugin(:activerecord, Activerecord)
  end
end
