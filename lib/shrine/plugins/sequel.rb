require "sequel"

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
    # * `after_commit` -- Promote the attachment and deletes the previous one.
    # * `after_destroy_commit` -- Deletes the attachment.
    #
    # Note that if your tests are wrapped in transactions, the `after_commit`
    # and `after_destroy_commit` callbacks won't get called, so in order to
    # test uploading you should first disable these transactions for those
    # tests.
    #
    # If you want to put some parts of this lifecycle into a background job, see
    # the background_helpers plugin.
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
        def initialize(name, *args)
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
              #{name}_attacher.save
            end

            def after_commit
              super
              #{name}_attacher.replace
              #{name}_attacher._promote
            end

            def after_destroy_commit
              super
              #{name}_attacher.destroy
            end
          RUBY
        end
      end

      module AttacherClassMethods
        # Needed by the background_helpers plugin.
        def find_record(record_class, record_id)
          record_class.with_pk!(record_id)
        end
      end

      module AttacherMethods
        # We save the record after promoting, raising any validation errors.
        def promote(cached_file)
          super
          record.save(raise_on_failure: true)
        end

        private

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

    register_plugin(:sequel, Sequel)
  end
end
