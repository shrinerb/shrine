class Shrine
  module Plugins
    # The copy plugin allows copying attachment from one record to another.
    #
    #     plugin :copy
    #
    # It adds a `Attacher#copy` method, which accepts another attacher, and
    # copies the attachment from it:
    #
    #     photo.image_attacher.copy(other_photo.image_attacher)
    #
    # This method will automatically be called when the record is duplicated:
    #
    #     duplicated_photo = photo.dup
    #     duplicated_photo.image #=> #<Shrine::UploadedFile>
    #     duplicated_photo.image != photo.image
    module Copy
      module AttachmentMethods
        def initialize(*)
          super

          module_eval <<-RUBY
            def initialize_copy(record)
              super
              @#{@name}_attacher = nil # reload the attacher
              self.#{@name}_data = nil # remove original attachment
              #{@name}_attacher.copy(record.#{@name}_attacher)
            end
          RUBY
        end
      end

      module AttacherMethods
        def copy(attacher)
          options = {action: :copy, move: false}

          if attacher.cached?
            copied_attachment = cache!(attacher.get, **options)
          elsif attacher.stored?
            copied_attachment = store!(attacher.get, **options)
          else
            copied_attachment = nil
          end

          set(copied_attachment)
        end
      end
    end

    register_plugin(:copy, Copy)
  end
end
