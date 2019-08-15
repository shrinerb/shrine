# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/model.md] on GitHub.
    #
    # [doc/plugins/model.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/model.md
    module Model
      def self.load_dependencies(uploader, **)
        uploader.plugin :entity
      end

      def self.configure(uploader, **opts)
        uploader.opts[:model] ||= { cache: true }
        uploader.opts[:model].merge!(opts)
      end

      module AttachmentMethods
        # Allows specifying whether the attachment should be for a model
        # (default) or an entity.
        #
        #     Shrine::Attachment.new(:image)                # model (default)
        #     Shrine::Attachment.new(:image, type: :model)  # model
        #     Shrine::Attachment.new(:image, type: :entity) # entity
        def initialize(name, **options)
          super(name, type: :model, **options)
        end

        # We define the setter dynamically on inclusion to allow other plugins
        # to still have time to override attachment type on inclusion.
        def included(klass)
          super

          return unless options[:type] == :model

          name = attachment_name

          define_method :"#{name}=" do |value|
            send(:"#{name}_attacher").model_assign(value)
          end

          define_method :initialize_copy do |other|
            super(other)
            instance_variable_set(:"@#{name}_attacher", instance_variable_get(:"@#{name}_attacher")&.dup)
            self
          end
          private :initialize_copy
        end

        # Memoizes the attacher instance into an instance variable.
        def attacher(record, options)
          return super unless @options[:type] == :model

          name = attachment_name

          if !record.instance_variable_get(:"@#{name}_attacher") || options.any?
            record.instance_variable_set(:"@#{name}_attacher", super)
          else
            record.instance_variable_get(:"@#{name}_attacher")
          end
        end
      end

      module AttacherClassMethods
        # Initializes itself from a model instance and attachment name.
        #
        #     photo.image_data #=> "{...}" # a file is attached
        #
        #     attacher = Attacher.from_model(photo, :image)
        #     attacher.file #=> #<Shrine::UploadedFile>
        def from_model(record, name, type: :model, **options)
          attacher = new(**options)
          attacher.load_model(record, name, type: type)
          attacher
        end
      end

      module AttacherMethods
        def initialize(model_cache: shrine_class.opts[:model][:cache], **options)
          super(**options)
          @model_cache = model_cache
        end

        # Saves record and name and initializes attachment from the model
        # attribute. Called from `Attacher.from_model`.
        def load_model(record, name, type: :model)
          load_entity(record, name, type: type)
        end

        # Called by the attachment attribute setter on the model.
        def model_assign(value, **options)
          if model_cache?
            assign(value, **options)
          else
            attach(value, **options)
          end
        end

        # Writes uploaded file data into the model.
        def set(*args)
          result = super
          write if model?
          result
        end

        # Writes the attachment data into the model attribute.
        def write
          column_values.each do |name, value|
            write_attribute(name, value)
          end
        end

        private

        # Writes given value into the model attribute.
        def write_attribute(name = attribute, value)
          record.public_send(:"#{name}=", value)
        end

        # Returns whether assigned files should be uploaded to/loaded from
        # temporary storage.
        def model_cache?
          @model_cache
        end

        # Returns whether the attacher is being backed by a model instance.
        # This allows users to still use the attacher with an entity instance
        # or without any record instance.
        def model?
          type == :model
        end
      end
    end

    register_plugin(:model, Model)
  end
end
