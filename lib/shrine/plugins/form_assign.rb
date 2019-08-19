# frozen_string_literal: true

class Shrine
  module Plugins
    module FormAssign
      def self.load_dependencies(uploader)
        uploader.plugin :entity
      end

      def self.configure(uploader, **opts)
        uploader.opts[:form_assign] ||= { result: :params }
        uploader.opts[:form_assign].merge!(opts)
      end

      module AttacherMethods
        # Helper for setting the attachment from form fields. Returns normalized
        # fields.
        #
        #     attacher = Shrine::Attacher.from_entity(photo, :image)
        #
        #     attacher.form_assign({ image: file, title: "Title" })
        #     #=> { image: '{...}', title: "Title" }
        #
        #     attacher.form_assign({ image: "", image_remote_url: "...", title: "Title" })
        #     #=> { image: '{...}', title: "Title" }
        #
        #     attacher.form_assign({ image: "", title: "Title" })
        #     #=> { title: "Title" }
        #
        # You can also return the result in form of attributes to be used for
        # database record creation.
        #
        #     attacher.form_assign({ image: file, title: "Title" }, result: :attributes)
        #     #=> { image_data: '{...}', title: "Title" }
        def form_assign(fields, result: shrine_class.opts[:form_assign][:result])
          form   = create_form_object
          fields = form_write(form, fields)

          form_attach(form)

          form_result(fields, result)
        end

        private

        # Assigns form params to the form object using Shrine's attachment
        # writers.
        def form_write(form, fields)
          result = fields.dup

          fields.each do |key, value|
            if form.respond_to?(:"#{key}=")
              form.send(:"#{key}=", value)

              result.delete(key)
            end
          end

          result
        end

        # Attaches the file from the form object if atachment has changed.
        def form_attach(form)
          return unless form.send(:"#{name}_attacher").changed?

          file = form.send(:"#{name}_attacher").file

          if file
            change uploaded_file(file.data) # use our UploadedFile class
          else
            change nil
          end
        end

        # Adds attached file data to the fields if attachment has changed.
        def form_result(fields, result_type)
          return fields unless changed?

          case result_type
          when :params     then fields[name]            = file&.to_json
          when :attributes then fields[:"#{name}_data"] = column_data
          else
            fail ArgumentError, "unrecognized result type: #{result_type.inspect}"
          end

          fields
        end

        # Creates a disposable form object with model plugin loaded.
        def create_form_object
          # load the model plugin into a disposable Shrine subclass
          shrine_subclass = Class.new(shrine_class)
          shrine_subclass.plugin :model

          # create a model class with attachment methods
          form_class = Struct.new(:"#{name}_data")
          form_class.include shrine_subclass::Attachment(name)

          # instantiate form object
          form_class.new(column_data)
        end
      end
    end

    register_plugin(:form_assign, FormAssign)
  end
end
