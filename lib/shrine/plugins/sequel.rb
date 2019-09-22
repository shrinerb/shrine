# frozen_string_literal: true

require "sequel"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/sequel.md] on GitHub.
    #
    # [doc/plugins/sequel.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/sequel.md
    module Sequel
      def self.load_dependencies(uploader, **)
        uploader.plugin :model
        uploader.plugin :_persistence, plugin: self
      end

      def self.configure(uploader, **opts)
        if opts.key?(:callbacks)
          Shrine.deprecation("The :callbacks option in sequel plugin has been renamed to :hooks. The :callbacks alias will be removed in Shrine 4.")
          opts[:hooks] = opts.delete(:callbacks)
        end

        uploader.opts[:sequel] ||= { hooks: true, validations: true }
        uploader.opts[:sequel].merge!(opts)
      end

      module AttachmentMethods
        def included(model)
          super

          return unless model < ::Sequel::Model

          name = @name

          if shrine_class.opts[:sequel][:validations]
            define_method :validate do
              super()
              send(:"#{name}_attacher").send(:sequel_validate)
            end
          end

          if shrine_class.opts[:sequel][:hooks]
            define_method :before_save do
              super()
              send(:"#{name}_attacher").send(:sequel_before_save)
            end

            define_method :after_save do
              super()
              send(:"#{name}_attacher").send(:sequel_after_save)
            end

            define_method :after_destroy do
              super()
              send(:"#{name}_attacher").send(:sequel_after_destroy)
            end
          end

          # reload the attacher on record reload
          define_method :_refresh do |*args|
            result = super(*args)
            instance_variable_set(:"@#{name}_attacher", nil)
            result
          end
          private :_refresh
        end
      end

      # The _persistence plugin uses #sequel_persist, #sequel_reload and
      # #sequel? to implement the following methods:
      #
      #   * Attacher#persist
      #   * Attacher#atomic_persist
      #   * Attacher#atomic_promote
      module AttacherMethods
        private

        # Adds file validation errors to the model. Called on model validation.
        def sequel_validate
          return unless respond_to?(:errors)

          errors.each do |message|
            record.errors.add(name, *message)
          end
        end

        # Calls Attacher#save. Called before model save.
        def sequel_before_save
          return unless changed?

          save
        end

        # Finalizes attachment and persists changes. Called after model save.
        def sequel_after_save
          return unless changed?

          record.db.after_commit do
            finalize
            persist
          end
        end

        # Deletes attached files. Called after model destroy.
        def sequel_after_destroy
          return unless attached?

          record.db.after_commit do
            destroy_attached
          end
        end

        # Saves changes to the model instance, skipping validations. Used by
        # the _persistence plugin.
        def sequel_persist
          record.save_changes(validate: false)
        end

        # Locks the database row and yields the reloaded record. Used by the
        # _persistence plugin.
        def sequel_reload
          record.db.transaction { yield record.dup.lock! }
        end

        # Returns true if the data attribute represents a JSON or JSONB column.
        # Used by the _persistence plugin to determine whether serialization
        # should be skipped.
        def sequel_hash_attribute?
          column = record.class.db_schema[attribute]
          column && [:json, :jsonb].include?(column[:type])
        end

        # Returns whether the record is a Sequel model. Used by the
        # _persistence plugin.
        def sequel?
          record.is_a?(::Sequel::Model)
        end
      end
    end

    register_plugin(:sequel, Sequel)
  end
end
