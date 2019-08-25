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
      end

      # Defines the following attacher methods for a persistence plugin:
      #
      # * #persist (calls #<name>_persist and #<name>?)
      # * #atomic_persist (calls #<name>_reload, #<name>_persist and #<name>?)
      # * #atomic_promote (calls #<name>_reload, #<name>_persist and #<name>?)
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

          define_method :persist do |*args, &block|
            return super(*args, &block) unless send(:"#{plugin_name}?")

            send(:"#{plugin_name}_persist")
          end
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
      end
    end

    register_plugin(:_persistence, Persistence)
  end
end
