# frozen_string_literal: true

class Shrine
  module Plugins
    module Copy
      module AttachmentMethods
        def initialize(*)
          super

          name = attachment_name

          define_method :initialize_copy do |record|
            super(record)
            instance_variable_set(:"@#{name}_attacher", nil) # reload the attacher
            attacher = send(:"#{name}_attacher")
            attacher.send(:write, nil) # remove original attachment
            attacher.copy(record.public_send(:"#{name}_attacher"))
          end

          # Fix for JRuby
          private :initialize_copy
        end
      end

      module AttacherMethods
        def copy(attacher)
          options = {action: :copy, move: false}

          copied_attachment = if attacher.cached?
                                cache!(attacher.get, **options)
                              elsif attacher.stored?
                                store!(attacher.get, **options)
                              else
                                nil
                              end

          @old = get
          _set(copied_attachment)
        end
      end
    end

    register_plugin(:copy, Copy)
  end
end
