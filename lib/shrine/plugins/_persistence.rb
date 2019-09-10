# frozen_string_literal: true

class Shrine
  module Plugins
    # Helper plugin that defines persistence methods on the attacher according
    # to convention.
    #
    #     plugin :_persistence, plugin: MyPlugin
    module Persistence
      def self.load_dependencies(uploader, *)
        uploader.plugin :atomic_helpers
        uploader.plugin :entity
      end

      # Using #<name>_persist, #<name>_reload, and #<name>?, defines the
      # following methods for a persistence plugin:
      #
      #   * Attacher#persist
      #   * Attacher#atomic_persist
      #   * Attacher#atomic_promote
      def self.configure(uploader, plugin:)
        plugin_name = plugin.to_s.split("::").last.downcase

        plugin::AttacherMethods.module_eval do
          define_method :atomic_promote do |**options, &block|
            return super(**options, &block) unless send(:"#{plugin_name}?")

            abstract_atomic_promote(
              reload:  method(:"#{plugin_name}_reload"),
              persist: method(:"#{plugin_name}_persist"),
              **options, &block
            )
          end

          define_method :atomic_persist do |*args, **options, &block|
            return super(*args, **options, &block) unless send(:"#{plugin_name}?")

            abstract_atomic_persist(
              *args,
              reload:  method(:"#{plugin_name}_reload"),
              persist: method(:"#{plugin_name}_persist"),
              **options, &block
            )
          end

          define_method :persist do
            return super() unless send(:"#{plugin_name}?")

            send(:"#{plugin_name}_persist")
          end

          define_method :hash_attribute? do
            return super() unless send(:"#{plugin_name}?")

            respond_to?(:"#{plugin_name}_hash_attribute?", true) &&
            send(:"#{plugin_name}_hash_attribute?")
          end
          private :hash_attribute?
        end
      end

      module AttacherMethods
        def atomic_promote(*)
          raise NotImplementedError, "unhandled by a persistence plugin"
        end

        def atomic_persist(*)
          raise NotImplementedError, "unhandled by a persistence plugin"
        end

        def persist(*)
          raise NotImplementedError, "unhandled by a persistence plugin"
        end

        # Disable attachment data serialization for data attributes that
        # accept and return hashes.
        def set_entity(*)
          super
          @column_serializer = nil if hash_attribute?
        end

        private

        # Whether the data attribute accepts and returns hashes.
        def hash_attribute?
          false
        end
      end
    end

    register_plugin(:_persistence, Persistence)
  end
end
