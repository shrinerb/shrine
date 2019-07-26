# frozen_string_literal: true

class Shrine
  module Plugins
    # The entity plugin allows the attacher to be initialized from an
    # **immutable** struct.
    #
    #     class Photo
    #       attr_reader :image_data
    #     end
    #
    #     photo = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')
    #
    #     attacher = Shrine::Attacher.from_entity(photo, :image)
    #     attacher.file #=> #<Shrine::UploadedFile>
    #
    # ## Attachment module
    #
    # It's also possible to operate with the attacher through the attachment
    # module included into the entity.
    #
    #     class Photo
    #       include Shrine::Attachment(:image)
    #       attr_reader :image_data
    #     end
    #
    #     photo = Photo.new(image_data: '{"id":"...","storage":"...","metadata":{...}}')
    #     photo.image_attacher #=> #<Shrine::Attacher>
    #
    #     photo.image     #=> #<Shrine::UploadedFile>
    #     photo.image_url #=> "..."
    module Entity
      def self.load_dependencies(uploader, **)
        uploader.plugin :column
      end

      module AttachmentMethods
        # Defines `#<name>`, `#<name>_url`, and `#<name>_attacher` methods.
        def initialize(name, **options)
          super

          attachment = self

          # Returns an attacher instance.
          define_method :"#{name}_attacher" do |**options|
            attachment.attacher(self, options)
          end

          # Returns the attached file.
          define_method :"#{name}" do |*args|
            send(:"#{name}_attacher").get(*args)
          end

          # Returns the URL to the attached file.
          define_method :"#{name}_url" do |*args|
            send(:"#{name}_attacher").url(*args)
          end
        end

        # Creates an instance of the corresponding Attacher subclass. It's not
        # memoized because the entity object could be frozen.
        def attacher(record, options)
          shrine_class::Attacher.from_entity(record, @name, @options.merge(options))
        end
      end

      module AttacherClassMethods
        # Initializes itself from an entity instance and attachment name.
        #
        #     photo.image_data #=> "{...}" # a file is attached
        #
        #     attacher = Attacher.from_entity(photo, :image)
        #     attacher.file #=> #<Shrine::UploadedFile>
        def from_entity(record, name, type: :entity, **options)
          attacher = new(**options)
          attacher.load_entity(record, name, type: type)
          attacher
        end
      end

      module AttacherMethods
        attr_reader :record, :name

        # Saves record and name and initializes attachment from the entity
        # attribute. Called from `Attacher.from_entity`.
        def load_entity(record, name, type: :entity)
          @record = record
          @name   = name.to_sym
          @type   = type

          @context.merge!(record: record, name: name)

          read
        end

        # Overwrites the current attachment with the one from model attribute.
        #
        #     photo.image_data #=> nil
        #     attacher = Shrine::Attacher.new(photo, :image)
        #     photo.image_data = uploaded_file.to_json
        #
        #     attacher.file #=> nil
        #     attacher.reload
        #     attacher.file #=> #<Shrine::UploadedFile>
        def reload
          read
          self
        end

        # Returns a hash with entity attribute name and column value.
        #
        #     attacher.column_values
        #     #=> { image_data: '{"id":"...","storage":"...","metadata":{...}}' }
        def column_values
          { attribute => column_value }
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

        # Returns whether the attacher has been loaded from an entity instance.
        def entity?
          type == :entity
        end

        attr_reader :type
      end
    end

    register_plugin(:entity, Entity)
  end
end
