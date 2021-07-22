# frozen_string_literal: true

require "pathname"

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/infer_extension
    module InferExtension
      LOG_SUBSCRIBER = -> (event) do
        Shrine.logger.info "Extension (#{event.duration}ms) – #{{
          mime_type: event[:mime_type],
          uploader:  event[:uploader],
        }.inspect}"
      end

      def self.configure(uploader, log_subscriber: LOG_SUBSCRIBER, **opts)
        uploader.opts[:infer_extension] ||= { inferrer: :mini_mime }
        uploader.opts[:infer_extension].merge!(opts)

        # instrumentation plugin integration
        uploader.subscribe(:extension, &log_subscriber) if uploader.respond_to?(:subscribe)
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

        # Sends a `extension.shrine` event for instrumentation plugin.
        def instrument_extension(mime_type, &block)
          return yield unless respond_to?(:instrument)

          instrument(:extension, mime_type: mime_type, &block)
        end
      end

      module InstanceMethods
        def infer_extension(mime_type)
          self.class.infer_extension(mime_type)
        end

        private

        def basic_location(io, metadata:)
          location = Pathname(super)

          if location.extname.empty? || opts[:infer_extension][:force]
            inferred_extension = self.class.infer_extension(metadata["mime_type"])
            location = location.sub_ext(inferred_extension) if inferred_extension
          end

          location.to_s
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
