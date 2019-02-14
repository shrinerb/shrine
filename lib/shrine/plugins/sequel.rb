# frozen_string_literal: true

require "sequel"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/sequel.md] on GitHub.
    #
    # [doc/plugins/sequel.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/sequel.md
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
              send(:"#{name}_attacher").errors.each do |message|
                errors.add(name, *message)
              end
            end
          end

          if shrine_class.opts[:sequel_callbacks]
            define_method :before_save do
              super()
              attacher = send(:"#{name}_attacher")
              attacher.save if attacher.changed?
            end

            define_method :after_save do
              super()
              attacher = send(:"#{name}_attacher")
              db.after_commit { attacher.finalize } if attacher.changed?
            end

            define_method :after_destroy do
              super()
              attacher = send(:"#{name}_attacher")
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
