# frozen_string_literal: true

class Shrine
  module Plugins
    module Derivates
      def self.load_dependencies(uploader, *)
        uploader.plugin :default_url
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:derivates_attribute] = opts.fetch(:data_attribute, :separate) # values are separate or original
        uploader.opts[:version_fallbacks] = opts.fetch(:fallbacks, uploader.opts.fetch(:version_fallbacks, {}))
        uploader.opts[:versions_fallback_to_original] = opts.fetch(:fallback_to_original, uploader.opts.fetch(:versions_fallback_to_original, true))

        unless [:separate, :original].include? uploader.opts[:derivates_attribute]
          raise Error, "`#{uploader.opts[:derivates_attribute] || "nil"}` is an invalid " \
            "option for `data_attribute` in Derivates Plugin. Valid options are: " \
            "[:separate, :original]"
        end
      end

      module ClassMethods
        def version_fallbacks
          opts[:version_fallbacks]
        end
      end

      module AttachmentMethods
        def initialize(name, **options)
          super

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}_derivates
              #{name}_attacher.get_derivates
            end
          RUBY
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

        def add_derivate(key, io, store = :store, nested_list = nil)
          @derivates_queue ||= {}
          if store == :store
            @derivates_queue.merge! key.to_sym => store!(io)
          else
            derivate_attacher = shrine_class::Attacher.new(context[:record], context[:name], cache: @cache.storage_key, store: store)
            @derivates_queue.merge! key.to_sym => derivate_attacher.store!(io)
          end
        end

        def update_derivates
          if instance_variable_defined?(:@derivates_queue)
            _set_derivates(@derivates_queue)
            remove_instance_variable(:@derivates_queue)
          end
        end

        def get
          data = read
          if data
            if derivates_attribute == :original
              data = JSON.parse(data)
              data.delete "derivates" if data.has_key? "derivates"
            end
            uploaded_file(data)
          end
        end

        def get_derivates
          data = read_derivates
          data = JSON.parse(data) if data
          convert_to_uploaded_file(data["derivates"])
        end

        private

        def convert_to_uploaded_file(object)
          return nil if object.nil?

          if object.is_a?(Hash) && object.values.none? { |value| value.is_a?(String) }
            object.inject({}) do |result, (name, value)|
              result.merge!(name.to_sym => convert_to_uploaded_file(value))
            end
          elsif object.is_a?(Array)
            object.map { |value| convert_to_uploaded_file(value) }
          else
            uploaded_file(object)
          end
        end

        def derivates_attribute
          shrine_class.opts[:derivates_attribute]
        end

        def _set_derivates(uploaded_file)
          data = convert_to_data(uploaded_file) if uploaded_file
          if data && derivates_attribute == :original
            record_data = get.data
            data = record_data.merge derivates: data
          end
          write_derivates(data ? convert_before_write(data) : nil)
        end

        def derivates_data_attribute
          if derivates_attribute == :separate
            :"#{name}_derivates_data"
          else
            :"#{name}_data"
          end
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
