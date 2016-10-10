require "sequel"

class Shrine
  module Plugins
    # The `sequel` plugin extends the "attachment" interface with support for
    # Sequel.
    #
    #     plugin :sequel
    #
    # ## Callbacks
    #
    # Now the attachment module will add additional callbacks to the model:
    #
    # * "before save" -- Used by the `recache` plugin.
    # * "after commit" (save) -- Promotes the attachment, deletes replaced ones.
    # * "after commit" (destroy) -- Deletes the attachment.
    #
    # Also note that if your tests are wrapped in transactions, the
    # "after commit" callbacks won't get called, so in order to test uploading
    # you should first disable transactions for those tests.
    #
    # If you want to put promoting/deleting into a background job, see the
    # `backgrounding` plugin.
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
    #         elsif changed_columns.include?(:avatar) && avatar_attacher.stored?
    #           # promoted
    #         end
    #       end
    #     end
    #
    # If you don't want the attachment module to add any callbacks to the
    # model, and would instead prefer to call these actions manually, you can
    # disable callbacks:
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
    # If don't want the attachment module to merge file validations errors into
    # model errors, you can disable it:
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

            def after_save
              super
              db.after_commit{#{@name}_attacher.finalize} if #{@name}_attacher.attached?
            end

            def after_destroy
              super
              db.after_commit{#{@name}_attacher.destroy} if #{@name}_attacher.read
            end
          RUBY
        end
      end

      module AttacherClassMethods
        # Needed by the `backgrounding` plugin.
        def find_record(record_class, record_id)
          record_class.with_pk(record_id)
        end
      end

      module AttacherMethods
        private

        # Saves the record after assignment, skipping validations.
        def update(uploaded_file)
          super
          record.save_changes(validate: false)
        end

        # If the data represents a JSON column with `pg_json` Sequel extension
        # loaded, a `Sequel::Postgres::JSONHashBase` object will be returned,
        # which we convert into a Hash.
        def convert_after_read(value)
          sequel_json_column? ? value.to_hash : super
        end

        # Returns true if the data attribute represents a JSON or JSONB column.
        def sequel_json_column?
          return false unless record.is_a?(::Sequel::Model)
          return false unless column = record.class.db_schema[data_attribute]

          [:json, :jsonb].include?(column[:type])
        end
      end
    end

    register_plugin(:sequel, Sequel)
  end
end
