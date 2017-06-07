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
    # * "before save" -- Used by the `recache` plugin.
    # * "after commit" (save) -- Promotes the attachment, deletes replaced ones.
    # * "after commit" (destroy) -- Deletes the attachment.
    #
    # Note that ActiveRecord versions 3.x and 4.x have errors automatically
    # silenced in hooks, which can make debugging more difficult, so it's
    # recommended that you enable errors:
    #
    #     # This is the default in ActiveRecord 5
    #     ActiveRecord::Base.raise_in_transactional_callbacks = true
    #
    # If you want to put promoting/deleting into a background job, see the
    # `backgrounding` plugin.
    #
    # Since attaching first saves the record with a cached attachment, then
    # saves again with a stored attachment, you can detect this in callbacks:
    #
    #     class User < ActiveRecord::Base
    #       include ImageUploader::Attachment.new(:avatar)
    #
    #       before_save do
    #         if avatar_data_changed? && avatar_attacher.cached?
    #           # cached
    #         elsif avatar_data_changed? && avatar_attacher.stored?
    #           # promoted
    #         end
    #       end
    #     end
    #
    # If you don't want the attachment module to add any callbacks to the
    # model, and would instead prefer to call these actions manually, you can
    # disable callbacks:
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
    #       include ImageUploader::Attachment.new(:avatar)
    #       validates_presence_of :avatar
    #     end
    #
    # If don't want the attachment module to merge file validations errors into
    # model errors, you can disable it:
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
              #{@name}_attacher.save if #{@name}_attacher.changed?
            end

            after_commit on: [:create, :update] do
              #{@name}_attacher.finalize if #{@name}_attacher.changed?
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
        # Support for Postgres JSON columns.
        def _set(uploaded_file)
          data = case record.class.columns_hash["#{name}_data"].type
                 when :json, :jsonb
                   uploaded_file
                 else
                   uploaded_file.to_json
                 end
          write(data ? data : nil)
        end

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
