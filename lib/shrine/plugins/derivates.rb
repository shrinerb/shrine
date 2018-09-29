# frozen_string_literal: true

class Shrine
  module Plugins
    module Derivates
      def self.load_dependencies(uploader, *)
        uploader.plugin :default_url
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:version_fallbacks] = opts.fetch(:fallbacks, uploader.opts.fetch(:version_fallbacks, {}))
        uploader.opts[:versions_fallback_to_original] = opts.fetch(:fallback_to_original, uploader.opts.fetch(:versions_fallback_to_original, true))
      end

      module ClassMethods
        def version_fallbacks
          opts[:version_fallbacks]
        end
      end


      module AttacherMethods
        def changed?
          instance_variable_defined?(:@old) || instance_variable_defined?(:@derivates_queue)
        end

        def finalize
          super
          update_derivates
        end

        def add_derivate(key, io, store = nil, nested_list = nil)
          @derivates_queue ||= {}

          @derivates_queue.merge! key.to_sym => store!(io)
        end

        def update_derivates
          if instance_variable_defined?(:@derivates_queue)
            _set_derivates(@derivates_queue)
            remove_instance_variable(:@derivates_queue)
          end
        end

        private

        def _set_derivates(uploaded_file)
          data = convert_to_data(uploaded_file) if uploaded_file
          write_derivates(data ? convert_before_write(data) : nil)
        end

        def derivates_data_attribute
          :"#{name}_derivates_data"
        end

        def read_derivates
          value = record.send(derivates_data_attribute)
          convert_after_read(value) unless value.nil? || value.empty?
        end

        def write_derivates(value)
          record.send(:"#{derivates_data_attribute}=", value)
        end

        def fallback_to_original?
          shrine_class.opts[:versions_fallback_to_original]
        end

        # Converts the Hash/Array of UploadedFile objects into a Hash/Array of data.
        def convert_to_data(object)
          if object.is_a?(Hash)
            object.inject({}) do |hash, (name, value)|
              hash.merge!(name => convert_to_data(value))
            end
          elsif object.is_a?(Array)
            object.map { |value| convert_to_data(value) }
          else
            super
          end
        end
      end
    end

    register_plugin(:derivates, Derivates)
  end
end
