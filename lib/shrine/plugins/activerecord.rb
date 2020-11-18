# frozen_string_literal: true

require "active_record"

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/activerecord
    module Activerecord
      def self.load_dependencies(uploader, **)
        uploader.plugin :model
        uploader.plugin :_persistence, plugin: self
      end

      def self.configure(uploader, **opts)
        uploader.opts[:activerecord] ||= { callbacks: true, validations: true }
        uploader.opts[:activerecord].merge!(opts)
      end

      module AttachmentMethods
        def included(model)
          super

          return unless model < ::ActiveRecord::Base

          name = @name

          if shrine_class.opts[:activerecord][:validations]
            model.validate do
              send(:"#{name}_attacher").send(:activerecord_validate)
            end
          end

          if shrine_class.opts[:activerecord][:callbacks]
            model.before_save do
              if send(:"#{name}_attacher").changed?
                send(:"#{name}_attacher").send(:activerecord_before_save)
              end
            end

            [:create, :update].each do |action|
              model.after_commit on: action do
                if send(:"#{name}_attacher").changed?
                  send(:"#{name}_attacher").send(:activerecord_after_save)
                end
              end
            end

            model.after_commit on: :destroy do
              if send(:"#{name}_attacher").attached?
                send(:"#{name}_attacher").send(:activerecord_after_destroy)
              end
            end
          end

          # reload the attacher on record reload
          define_method :reload do |*args|
            result = super(*args)
            send(:"#{name}_attacher").reload if instance_variable_defined?(:"@#{name}_attacher")
            result
          end
        end
      end

      # The _persistence plugin uses #activerecord_persist,
      # #activerecord_reload and #activerecord? to implement the following
      # methods:
      #
      #   * Attacher#persist
      #   * Attacher#atomic_persist
      #   * Attacher#atomic_promote
      module AttacherMethods
        private

        # Adds file validation errors to the model. Called on model validation.
        def activerecord_validate
          return unless respond_to?(:errors)

          errors.each do |message|
            record.errors.add(name, *message)
          end
        end

        # Calls Attacher#save. Called before model save.
        def activerecord_before_save
          save
        end

        # Finalizes attachment and persists changes. Called after model save.
        def activerecord_after_save
          finalize
          persist
        end

        # Deletes attached files. Called after model destroy.
        def activerecord_after_destroy
          destroy_attached
        end

        # Saves changes to the model instance, skipping validations. Used by
        # the _persistence plugin.
        def activerecord_persist
          record.save(validate: false)
        end

        # Locks the database row and yields the reloaded record. Used by the
        # _persistence plugin.
        def activerecord_reload
          record.transaction { yield record.clone.reload(lock: true) }
        end

        # Returns true if the data attribute represents a JSON or JSONB column.
        # Used by the _persistence plugin to determine whether serialization
        # should be skipped.
        def activerecord_hash_attribute?
          column = record.class.columns_hash[attribute.to_s]
          column && [:json, :jsonb].include?(column.type)
        end

        # Returns whether the record is an ActiveRecord model. Used by the
        # _persistence plugin.
        def activerecord?
          record.is_a?(::ActiveRecord::Base)
        end
      end
    end

    register_plugin(:activerecord, Activerecord)
  end
end
