# frozen_string_literal: true

require "active_record"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/activerecord.md] on GitHub.
    #
    # [doc/plugins/activerecord.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/activerecord.md
    module Activerecord
      def self.configure(uploader, opts = {})
        uploader.opts[:activerecord_callbacks] = opts.fetch(:callbacks, uploader.opts.fetch(:activerecord_callbacks, true))
        uploader.opts[:activerecord_validations] = opts.fetch(:validations, uploader.opts.fetch(:activerecord_validations, true))
      end

      module AttachmentMethods
        def included(model)
          super

          return unless model < ::ActiveRecord::Base

          name = attachment_name

          if shrine_class.opts[:activerecord_validations]
            model.validate do
              send("#{name}_attacher").errors.each do |message|
                errors.add(name, *message)
              end
            end
          end

          if shrine_class.opts[:activerecord_callbacks]
            model.before_save do
              attacher = send("#{name}_attacher")
              attacher.save if attacher.changed?
            end

            [:create, :update].each do |action|
              model.after_commit on: action do
                attacher = send("#{name}_attacher")
                attacher.finalize if attacher.changed?
              end
            end

            model.after_commit on: :destroy do
              send("#{name}_attacher").destroy
            end
          end
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

        # If the data attribute represents a JSON column, it needs to receive a
        # Hash.
        def convert_before_write(value)
          activerecord_json_column? ? value : super
        end

        # Returns true if the data attribute represents a JSON or JSONB column.
        def activerecord_json_column?
          return false unless record.is_a?(ActiveRecord::Base)
          return false unless column = record.class.columns_hash[data_attribute.to_s]

          [:json, :jsonb].include?(column.type)
        end
      end
    end

    register_plugin(:activerecord, Activerecord)
  end
end
