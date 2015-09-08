class Uploadie
  module Plugins
    module StoreMetadata
      DEFAULT_OPTIONS = {filename: true, size: true, content_type: true}

      def self.load_dependencies(uploadie, *)
        uploadie.plugin :_metadata
        InstanceMethods.include(Metadata::Helpers)
      end

      def self.configure(uploadie, **options)
        raise Error, "must specify a library for extracting dimensions (e.g. `dimensions: :mini_magick`)" if options[:dimensions] == true
        uploadie.opts[:store_metadata] = DEFAULT_OPTIONS.merge(options)
        uploadie.opts[:store_metadata].each do |name, value|
          FileMethods.send("#{name}!") if value
        end
      end

      module InstanceMethods
        def extract_metadata(io, context)
          metadata_opts = opts[:store_metadata]

          metadata = super
          metadata["filename"] = _extract_filename(io) if metadata_opts[:filename]
          metadata["size"] = _extract_size(io) if metadata_opts[:size]
          metadata["content_type"] = _extract_content_type(io) if metadata_opts[:content_type]
          metadata["width"], metadata["height"] = _extract_dimensions(io, library: metadata_opts[:dimensions]) if metadata_opts[:dimensions]
          metadata
        end
      end

      module FileMethods
        def self.filename!
          define_method(:original_filename) do
            metadata.fetch("filename")
          end

          define_method(:extension) do
            File.extname(original_filename) if original_filename
          end
        end

        def self.size!
          define_method(:size) do
            metadata.fetch("size")
          end
        end

        def self.content_type!
          define_method(:content_type) do
            metadata.fetch("content_type")
          end
        end

        def self.dimensions!
          define_method(:width) do
            metadata.fetch("width")
          end

          define_method(:height) do
            metadata.fetch("height")
          end
        end
      end
    end

    register_plugin(:store_metadata, StoreMetadata)
  end
end
