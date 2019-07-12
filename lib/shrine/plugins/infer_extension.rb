# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/infer_extension.md] on GitHub.
    #
    # [doc/plugins/infer_extension.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/infer_extension.md
    module InferExtension
      LOG_SUBSCRIBER = -> (event) do
        Shrine.logger.info "Extension (#{event.duration}ms) – #{{
          mime_type: event[:mime_type],
          uploader:  event[:uploader],
        }.inspect}"
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:infer_extension] ||= { inferrer: :mime_types, force: false, log_subscriber: LOG_SUBSCRIBER }
        uploader.opts[:infer_extension].merge!(opts)

        # instrumentation plugin integration
        if uploader.respond_to?(:subscribe)
          uploader.subscribe(:metadata_extension) do |event|
            uploader.opts[:infer_extension][:log_subscriber]&.call(event)
          end
        end
      end

      module ClassMethods
        def infer_extension(mime_type)
          inferrer = opts[:infer_extension][:inferrer]
          inferrer = extension_inferrer(inferrer) if inferrer.is_a?(Symbol)
          args     = [mime_type, extension_inferrers].take(inferrer.arity.abs)

          instrument_extension(mime_type) { inferrer.call(*args) }
        end

        def extension_inferrers
          @extension_inferrers ||= ExtensionInferrer::SUPPORTED_TOOLS.inject({}) do |hash, tool|
            hash.merge!(tool => extension_inferrer(tool))
          end
        end

        def extension_inferrer(name)
          ExtensionInferrer.new(name).method(:call)
        end

        private

        # Send event for the instrumentation plugin.
        def instrument_extension(mime_type, &block)
          return yield unless respond_to?(:instrument)

          instrument(:metadata_extension, mime_type: mime_type, &block)
        end
      end

      module InstanceMethods
        def generate_location(io, context = {})
          mime_type = (context[:metadata] || {})["mime_type"]

          location = super
          current_extension = File.extname(location)

          if current_extension.empty? || opts[:infer_extension][:force]
            inferred_extension = infer_extension(mime_type)
            location = location.chomp(current_extension) << inferred_extension unless inferred_extension.empty?
          end

          location
        end

        private

        def infer_extension(mime_type)
          self.class.infer_extension(mime_type).to_s
        end
      end

      class ExtensionInferrer
        SUPPORTED_TOOLS = [:mime_types, :mini_mime]

        def initialize(tool)
          raise Error, "unknown extension inferrer #{tool.inspect}, supported inferrers are: #{SUPPORTED_TOOLS.join(",")}" unless SUPPORTED_TOOLS.include?(tool)

          @tool = tool
        end

        def call(mime_type)
          return nil if mime_type.nil?

          extension = send(:"infer_with_#{@tool}", mime_type)
          extension = ".#{extension}" unless extension.nil? || extension.start_with?(".")
          extension
        end

        private

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
