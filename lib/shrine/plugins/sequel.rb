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
        uploader.plugin :atomic_helpers
      end

      def self.configure(uploader, **opts)
        uploader.opts[:sequel] ||= { callbacks: true, validations: true }
        uploader.opts[:sequel].merge!(opts)
      end

      module AttachmentMethods
        def included(model)
          super

          return unless model < ::Sequel::Model

          name = attachment_name

          if shrine_class.opts[:sequel][:validations]
            define_method :validate do
              super()
              if send(:"#{name}_attacher").respond_to?(:errors)
                send(:"#{name}_attacher").errors.each do |message|
                  errors.add(name, *message)
                end
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
                  send(:"#{name}_attacher").sequel_persist
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

          define_method :_refresh do |*args|
            result = super(*args)
            instance_variable_set(:"@#{name}_attacher", nil)
            result
          end
          private :_refresh
        end
      end

      module AttacherMethods
        # Promotes cached file to permanent storage in an atomic way. It's
        # intended to be called from a background job.
        #
        #     attacher.assign(file)
        #     attacher.cached? #=> true
        #
        #     # ... in background job ...
        #
        #     attacher.atomic_promote
        #     attacher.stored? #=> true
        #
        # It accepts `:reload` and `:persist` strategies:
        #
        #     attacher.atomic_promote(reload: :lock)    # uses database locking (default)
        #     attacher.atomic_promote(reload: :fetch)   # reloads with no locking
        #     attacher.atomic_promote(reload: ->(&b){}) # custom reloader
        #     attacher.atomic_promote(reload: false)    # skips reloading
        #
        #     attacher.atomic_promote(persist: :save) # persists stored file (default)
        #     attacher.atomic_promote(persist: ->{})  # custom persister
        #     attacher.atomic_promote(persist: false) # skips persistence
        def sequel_atomic_promote(**options, &block)
          abstract_atomic_promote(sequel_strategies(**options), &block)
        end
        alias atomic_promote sequel_atomic_promote

        # Persist the the record only if the attachment hasn't changed.
        # Optionally yields reloaded attacher to the block before persisting.
        # It's intended to be called from a background job.
        #
        #     # ... in background job ...
        #
        #     attacher.file.metadata["foo"] = "bar"
        #     attacher.write
        #
        #     attacher.atomic_persist
        def sequel_atomic_persist(*args, **options, &block)
          abstract_atomic_persist(*args, sequel_strategies(**options), &block)
        end
        alias atomic_persist sequel_atomic_persist

        # Called in the `after_commit` callback after finalization.
        def sequel_persist
          sequel_save
        end
        alias persist sequel_persist

        private

        # Resolves strategies for atomic promotion and persistence.
        def sequel_strategies(reload: :lock, persist: :save, **options)
          reload  = method(:"sequel_#{reload}")  if reload.is_a?(Symbol)
          persist = method(:"sequel_#{persist}") if persist.is_a?(Symbol)

          { reload: reload, persist: persist, **options }
        end

        # Implements the "fetch" reload strategy for #sequel_promote.
        def sequel_fetch
          yield record.dup.refresh
        end

        # Implements the "lock" reload strategy for #sequel_promote.
        def sequel_lock
          record.db.transaction { yield record.dup.lock! }
        end

        # Implements the "save" persist strategy for #sequel_promote.
        def sequel_save
          record.save_changes(validate: false)
        end

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
          return false unless record.is_a?(::Sequel::Model)
          return false unless column = record.class.db_schema[attribute]

          [:json, :jsonb].include?(column[:type])
        end
      end
    end

    register_plugin(:sequel, Sequel)
  end
end
