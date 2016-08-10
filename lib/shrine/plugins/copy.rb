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
    #     duplicated_photo.image.id != photo.image.id
    module Copy
      module AttachmentMethods
        def initialize(*)
          super

          module_eval <<-RUBY
            def initialize_copy(record)
              super
              @#{@name}_attacher = nil # reload the attacher
              #{@name}_attacher.copy(record.#{@name}_attacher)
            end
          RUBY
        end
      end

      module AttacherMethods
        def copy(attacher)
          options = {action: :copy, move: false}

          if attacher.cached?
            set cache!(attacher.get, **options)
          elsif attacher.stored?
            set store!(attacher.get, **options)
          end
        end
      end
    end

    register_plugin(:copy, Copy)
  end
end
