require "sequel"

Sequel::Model.plugin :instance_filters

class Shrine
  module Plugins
    # The sequel plugin extends the "attachment" interface with support for
    # Sequel.
    #
    #     plugin :sequel
    #
    # Now whenever an "attachment" module is included, additional callbacks are
    # added to the model:
    #
    # * `before_save` -- Currently only used by the recache plugin.
    # * `after_commit` -- Promotes the attachment, deletes replaced ones.
    # * `after_destroy_commit` -- Deletes the attachment.
    #
    # Also note that if your tests are wrapped in transactions, the
    # `after_commit` callbacks won't get called, so in order to test uploading
    # you should first disable transactions for those tests.
    #
    # If you want to put some parts of this lifecycle into a background job,
    # see the backgrounding plugin.
    #
    # Additionally, any Shrine validation errors will added to Sequel's
    # errors upon validation. Note that if you want to validate presence of the
    # attachment, you can do it directly on the model.
    #
    #     class User < Sequel::Model
    #       include ImageUploader[:avatar]
    #       validates_presence_of :avatar
    #     end
    module Sequel
      module AttachmentMethods
        def initialize(name)
          super

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def validate
              super
              #{name}_attacher.errors.each do |message|
                errors.add(:#{name}, message)
              end
            end

            def before_save
              super
              #{name}_attacher.save if #{name}_attacher.attached?
            end

            def after_commit
              super
              #{name}_attacher.finalize if #{name}_attacher.attached?
            end

            def after_destroy_commit
              super
              #{name}_attacher.destroy
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

        # Updates the current attachment with the new one, unless the current
        # attachment has changed.
        def update(uploaded_file)
          if record.send("#{name}_data") == record.reload.send("#{name}_data")
            record.send("#{name}_data=", uploaded_file.to_json)
            record.save(validate: false)
          end
        rescue ::Sequel::NoExistingObject
        rescue ::Sequel::Error => error
          raise unless error.message == "Record not found" # prior to version 4.28
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
