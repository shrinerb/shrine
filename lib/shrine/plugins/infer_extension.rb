# frozen_string_literal: true

class Shrine
  module Plugins
    # The `infer_extension` plugin allows deducing the appropriate file
    # extension for the upload location based on the MIME type of the file.
    # This is useful when using `data_uri` and `remote_url` plugins, where the
    # file extension is not or might not be known.
    #
    #     plugin :infer_extension
    #
    # The upload location will gain the inferred extension only if couldn't be
    # determined from the filename. By default `Rack::Mime` will be used for
    # inferring the extension, but you can also choose a different inferrer:
    #
    #     plugin :infer_extension, inferrer: :mime_types
    #
    # The following inferrers are accepted:
    #
    # :rack_mime
    # : (Default). Uses the `Rack::Mime` module to infer the appropriate
    #   extension from MIME type.
    #
    # :mime_types
    # : Uses the [mime-types] gem to infer the appropriate extension from MIME
    #   type.
    #
    # :mini_mime
    # : Uses the [mini_mime] gem to infer the appropriate extension from MIME
    #   type.
    #
    # You can also define your own inferrer, with the possibility to call the
    # built-in inferrers:
    #
    #     plugin :infer_extension, inferrer: -> (mime_type, inferrers) do
    #       # don't add extension if the file is a text file
    #       inferrrs[:rack_mime].call(mime_type) unless mime_type == "text/plain"
    #     end
    #
    # You can also use methods for inferring extension directly:
    #
    #     Shrine.infer_extension("image/jpeg")
    #     # => ".jpeg"
    #
    #     Shrine.extension_inferrers[:mime_types].call("image/jpeg")
    #     # => ".jpeg"
    #
    # [mime-types]: https://github.com/mime-types/ruby-mime-types
    # [mini_mime]: https://github.com/discourse/mini_mime
    module InferExtension
      def self.configure(uploader, opts = {})
        uploader.opts[:extension_inferrer] = opts.fetch(:inferrer, uploader.opts.fetch(:infer_extension_inferrer, :rack_mime))
      end

      module ClassMethods
        def infer_extension(mime_type)
          inferrer = opts[:extension_inferrer]
          inferrer = extension_inferrers[inferrer] if inferrer.is_a?(Symbol)
          args     = [mime_type, extension_inferrers].take(inferrer.arity.abs)

          inferrer.call(*args)
        end

        def extension_inferrers
          @extension_inferrers ||= ExtensionInferrer::SUPPORTED_TOOLS.inject({}) do |hash, tool|
            hash.merge!(tool => ExtensionInferrer.new(tool).method(:call))
          end
        end
      end

      module InstanceMethods
        def generate_location(io, context = {})
          mime_type = (context[:metadata] || {})["mime_type"]

          location  = super
          location += infer_extension(mime_type) if File.extname(location).empty?
          location
        end

        private

        def infer_extension(mime_type)
          self.class.infer_extension(mime_type).to_s
        end
      end

      class ExtensionInferrer
        SUPPORTED_TOOLS = [:rack_mime, :mime_types, :mini_mime]

        def initialize(tool)
          raise ArgumentError, "unsupported extension inferrer tool: #{tool}" unless SUPPORTED_TOOLS.include?(tool)

          @tool = tool
        end

        def call(mime_type)
          return nil if mime_type.nil?

          extension = send(:"infer_with_#{@tool}", mime_type)
          extension = ".#{extension}" unless extension.nil? || extension.start_with?(".")
          extension
        end

        private

        def infer_with_rack_mime(mime_type)
          require "rack/mime"

          mime_types = Rack::Mime::MIME_TYPES
          mime_types.key(mime_type)
        end

        def infer_with_mime_types(mime_type)
          require "mime/types"

          mime_type = MIME::Types[mime_type].first
          mime_type.preferred_extension if mime_type
        end

        def infer_with_mini_mime(mime_type)
          require "mini_mime"

          info = MiniMime.lookup_by_content_type(mime_type)
          info.extension if info
        end
      end
    end

    register_plugin(:infer_extension, InferExtension)
  end
end
