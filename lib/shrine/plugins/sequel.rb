# frozen_string_literal: true

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
    # If you want to put promoting/deleting into a background job, see the
    # `backgrounding` plugin.
    #
    # Since attaching first saves the record with a cached attachment, then
    # saves again with a stored attachment, you can detect this in callbacks:
    #
    #     class User < Sequel::Model
    #       include ImageUploader::Attachment.new(:avatar)
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
    #       include ImageUploader::Attachment.new(:avatar)
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

          name = attachment_name

          if shrine_class.opts[:sequel_validations]
            define_method :validate do
              super()
              send("#{name}_attacher").errors.each do |message|
                errors.add(name, *message)
              end
            end
          end

          if shrine_class.opts[:sequel_callbacks]
            define_method :before_save do
              super()
              attacher = send("#{name}_attacher")
              attacher.save if attacher.changed?
            end

            define_method :after_save do
              super()
              attacher = send("#{name}_attacher")
              db.after_commit { attacher.finalize } if attacher.changed?
            end

            define_method :after_destroy do
              super()
              attacher = send("#{name}_attacher")
              db.after_commit { attacher.destroy } if attacher.read
            end
          end
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
