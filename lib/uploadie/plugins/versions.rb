class Uploadie
  module Plugins
    # plugin :versions, storage: :cache, processor: -> (raw_image, context) do
    #   size_700 = resize_to_fit(raw_image, 700, 700)
    #   size_500 = resize_to_fit(raw_image, 500, 500)
    #   size_300 = resize_to_fit(raw_image, 300, 300)
    #
    #   {large: size_700, medium: size_500, small: size_300}
    # end
    #
    module Versions
      def self.configure(uploadie, processor:, storage:)
        raise ArgumentError, ":processor must be a proc or a symbol" if !processor.is_a?(Proc) && !processor.is_a?(Symbol)
        uploadie.opts[:processor] = processor

        uploadie.storages.fetch(storage)
        uploadie.opts[:processing_storage] = storage
      end

      module InstanceMethods
        def upload(io, context = {})
          if io.is_a?(Hash)
            store(io, context)
          else
            super
          end
        end

        def store(io, context = {})
          if (hash = io).is_a?(Hash)
            hash.inject({}) do |versions, (name, version)|
              versions.update(name => super(version, version: name, **context))
            end
          elsif generate_versions?(io, context)
            processor = self.class.opts[:processor]
            processor = method(processor) if processor.is_a?(Symbol)
            io = io.download if io.is_a?(Uploadie::UploadedFile)

            processed = instance_exec(io, context, &processor)

            if processed.is_a?(Hash)
              store(processed, context)
            else
              super(processed, context)
            end
          else
            super
          end
        end

        private

        def generate_versions?(io, context)
          storage_key == self.class.opts[:processing_storage]
        end
      end

      module AttacherMethods
        def url(version = nil)
          if get.is_a?(Hash)
            if version
              get.fetch(version).url
            else
              raise Error, "must call #{name}_url with a name of the version"
            end
          else
            super
          end
        end

        def validate
          get.is_a?(Hash) ? [] : super
        end

        private

        def uploaded?(object)
          if object.is_a?(Hash)
            object.all? { |name, object| super(object) }
          else
            super
          end
        end

        def uploaded_file(hash)
          if hash.key?("storage")
            super
          else
            hash.inject({}) do |versions, (name, data)|
              versions.update(name.to_sym => super(data))
            end
          end
        end

        def data(uploaded_file)
          if (versions = uploaded_file).is_a?(Hash)
            versions.inject({}) do |hash, (name, version)|
              hash.update(name => super(version))
            end
          else
            super
          end
        end

        def stored?(uploaded_file)
          if (versions = uploaded_file).is_a?(Hash)
            versions.all? { |name, uploaded_file| super(uploaded_file) }
          else
            super
          end
        end

        def delete!(uploaded_file)
          if (versions = uploaded_file).is_a?(Hash)
            versions.each { |name, uploaded_file| super(uploaded_file) }
          else
            super
          end
        end
      end
    end

    register_plugin(:versions, Versions)
  end
end
