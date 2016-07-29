class Shrine
  module Plugins
    # The metadata plugin provides a convenient method for extracting and
    # adding custom metadata values.
    #
    #     plugin :add_metadata
    #
    #     add_metadata :exif do |io, context|
    #       MiniMagick::Image.new(io.path).exif
    #     end
    #
    # The above will add "exif" to the metadata hash, and also add the `#exif`
    # method to the `UploadedFile`:
    #
    #     uploaded_file.metadata["exif"]
    #     # or
    #     uploaded_file.exif
    module AddMetadata
      def self.configure(uploader)
        uploader.opts[:metadata] = {}
      end

      module ClassMethods
        def add_metadata(name, &block)
          opts[:metadata][name] = block

          self::UploadedFile.send(:define_method, name) do
            metadata[name.to_s]
          end
        end
      end

      module InstanceMethods
        def extract_metadata(io, context)
          metadata = super

          opts[:metadata].each do |name, block|
            value = instance_exec(io, context, &block)
            metadata[name.to_s] = value unless value.nil?
          end

          metadata
        end
      end
    end

    register_plugin(:add_metadata, AddMetadata)
  end
end
