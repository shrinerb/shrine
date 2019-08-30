# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/entity.md] on GitHub.
    #
    # [doc/plugins/entity.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/entity.md
    module Entity
      def self.load_dependencies(uploader, **)
        uploader.plugin :column
      end

      module AttachmentMethods
        def initialize(name, **options)
          super(name, **options)

          define_entity_methods(name)
        end

        private

        # Defines `#<name>`, `#<name>_url`, and `#<name>_attacher` methods.
        def define_entity_methods(name)
          super if defined?(super)

          attachment = self

          # Returns the attached file.
          define_method :"#{name}" do |*args|
            send(:"#{name}_attacher").get(*args)
          end

          # Returns the URL to the attached file.
          define_method :"#{name}_url" do |*args|
            send(:"#{name}_attacher").url(*args)
          end

          # Returns an attacher instance.
          define_method :"#{name}_attacher" do |**options|
            attachment.send(:attacher, self, options)
          end
        end

        # Creates an instance of the corresponding Attacher subclass. It's not
        # memoized because the entity object could be frozen.
        def attacher(record, options)
          attacher = record.class.send(:"#{@name}_attacher", options)
          attacher.load_entity(record, @name)
          attacher
        end
      end

      module AttacherClassMethods
        # Initializes itself from an entity instance and attachment name.
        #
        #     photo.image_data #=> "{...}" # a file is attached
        #
        #     attacher = Attacher.from_entity(photo, :image)
        #     attacher.file #=> #<Shrine::UploadedFile>
        def from_entity(record, name, **options)
          attacher = new(**options)
          attacher.load_entity(record, name)
          attacher
        end
      end

      module AttacherMethods
        attr_reader :record, :name

        # Saves record and name and initializes attachment from the entity
        # attribute. Called from `Attacher.from_entity`.
        def load_entity(record, name)
          set_entity(record, name)
          read
        end

        # Sets record and name without loading the attachment from the entity
        # attribute.
        def set_entity(record, name)
          @record = record
          @name   = name.to_sym

          @context.merge!(record: record, name: name)
        end

        # Overwrites the current attachment with the one from model attribute.
        #
        #     photo.image_data #=> nil
        #     attacher = Shrine::Attacher.from_entity(photo, :image)
        #     photo.image_data = uploaded_file.to_json
        #
        #     attacher.file #=> nil
        #     attacher.reload
        #     attacher.file #=> #<Shrine::UploadedFile>
        def reload
          read
          self
        end

        # Returns a hash with entity attribute name and column data.
        #
        #     attacher.column_values
        #     #=> { image_data: '{"id":"...","storage":"...","metadata":{...}}' }
        def column_values
          { attribute => column_data }
        end

        # Returns the entity attribute name used for reading and writing
        # attachment data.
        #
        #     attacher = Shrine::Attacher.from_entity(photo, :image)
        #     attacher.attribute #=> :image_data
        def attribute
          fail Shrine::Error, "record is not loaded" if name.nil?

          :"#{name}_data"
        end

        private

        # Loads attachment from the entity attribute.
        def read
          load_column(read_attribute)
        end

        # Reads value from the entity attribute.
        def read_attribute
          record.public_send(attribute)
        end
      end
    end

    register_plugin(:entity, Entity)
  end
end
