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
        uploader.opts[:sequel] ||= { callbacks: true, validations: true }
        uploader.opts[:sequel].merge!(opts)
      end

      module AttachmentMethods
        def included(model)
          super

          return unless model < ::Sequel::Model

          name = @name

          if shrine_class.opts[:sequel][:validations]
            # add validation plugin integration
            define_method :validate do
              super()
              return unless send(:"#{name}_attacher").respond_to?(:errors)

              send(:"#{name}_attacher").errors.each do |message|
                errors.add(name, *message)
              end
            end
          end

          if shrine_class.opts[:sequel][:callbacks]
            define_method :before_save do
              super()
              if send(:"#{name}_attacher").changed?
                send(:"#{name}_attacher").save
              end
            end

            define_method :after_save do
              super()
              if send(:"#{name}_attacher").changed?
                db.after_commit do
                  send(:"#{name}_attacher").finalize
                  send(:"#{name}_attacher").persist
                end
              end
            end

            define_method :after_destroy do
              super()
              if send(:"#{name}_attacher").attached?
                db.after_commit do
                  send(:"#{name}_attacher").destroy_attached
                end
              end
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

      module AttacherMethods
        # The _persistence plugin defines the following methods:
        #
        #   * #persist (calls #sequel_persist and #sequel?)
        #   * #atomic_persist (calls #sequel_lock, #sequel_persist and #sequel?)
        #   * #atomic_promote (calls #sequel_lock, #sequel_persist and #sequel?)
        private

        # Sequel JSON column attribute with `pg_json` Sequel extension loaded
        # returns a `Sequel::Postgres::JSONHashBase` object will be returned,
        # which we convert into a Hash.
        def deserialize_column(data)
          sequel_json_column? ? data&.to_hash : super
        end

        # Sequel JSON column attribute with `pg_json` Sequel extension loaded
        # can receive a Hash object, so there is no need to generate a JSON
        # string.
        def serialize_column(data)
          sequel_json_column? ? data : super
        end

        # Returns true if the data attribute represents a JSON or JSONB column.
        def sequel_json_column?
          return false unless sequel?
          return false unless column = record.class.db_schema[attribute]

          [:json, :jsonb].include?(column[:type])
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
