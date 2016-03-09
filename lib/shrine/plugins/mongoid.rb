require "mongoid"

class Shrine
  module Plugins
    # The mongoid plugin extends the "attachment" interface with support
    # for Mongoid.
    #
    #     plugin :mongoid
    #
    # Now whenever an "attachment" module is included, additional callbacks are
    # added to the model:
    #
    # * `before_save` -- Currently only used by the recache plugin.
    # * `after_create`, `after_update` -- Promotes the attachment, deletes replaced ones.
    # * `after_destroy` -- Deletes the attachment.
    #
    # If you want to put some parts of this lifecycle into a background job, see
    # the backgrounding plugin.
    #
    # Additionally, any Shrine validation errors will be added to Mongoid's
    # errors upon validation. Note that if you want to validate presence of the
    # attachment, you can do it directly on the model.
    #
    #     class User
    #       include Mongoid::Document
    #       include ImageUploader[:avatar]
    #
    #       field :avatar, type: String
    #
    #       validates_presence_of :avatar
    #     end
    module Mongoid
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

            after_create do
              #{@name}_attacher.finalize if #{@name}_attacher.attached?
            end

            after_update do
              #{@name}_attacher.finalize if #{@name}_attacher.attached?
            end

            after_destroy do
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
        def swap(uploaded_file)
          return if record.send("#{name}_data") != record.reload.send("#{name}_data")
          super
        rescue ::Mongoid::Errors::DocumentNotFound
        end

        # We save the record after updating, raising any validation errors.
        def update(uploaded_file)
          super
          record.save!
        end
      end
    end

    register_plugin(:mongoid, Mongoid)
  end
end
