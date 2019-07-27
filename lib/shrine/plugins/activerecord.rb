# frozen_string_literal: true

require "active_record"

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/activerecord.md] on GitHub.
    #
    # [doc/plugins/activerecord.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/activerecord.md
    module Activerecord
      def self.load_dependencies(uploader, **)
        uploader.plugin :model
        uploader.plugin :atomic_helpers
      end

      def self.configure(uploader, **opts)
        uploader.opts[:activerecord] ||= { callbacks: true, validations: true }
        uploader.opts[:activerecord].merge!(opts)
      end

      module AttachmentMethods
        def included(model)
          super

          return unless model < ::ActiveRecord::Base

          name = attachment_name

          if shrine_class.opts[:activerecord][:validations]
            model.validate do
              if send(:"#{name}_attacher").respond_to?(:errors)
                send(:"#{name}_attacher").errors.each do |message|
                  errors.add(name, *message)
                end
              end
            end
          end

          if shrine_class.opts[:activerecord][:callbacks]
            model.before_save do
              if send(:"#{name}_attacher").changed?
                send(:"#{name}_attacher").save
              end
            end

            [:create, :update].each do |action|
              model.after_commit on: action do
                if send(:"#{name}_attacher").changed?
                  send(:"#{name}_attacher").finalize
                  send(:"#{name}_attacher").activerecord_persist
                end
              end
            end

            model.after_commit on: :destroy do
              send(:"#{name}_attacher").destroy_attached
            end
          end

          define_method :reload do |*args|
            result = super(*args)
            instance_variable_set(:"@#{name}_attacher", nil)
            result
          end
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
        def activerecord_atomic_promote(**options, &block)
          abstract_atomic_promote(activerecord_strategies(**options), &block)
        end
        alias atomic_promote activerecord_atomic_promote

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
        def activerecord_atomic_persist(*args, **options, &block)
          abstract_atomic_persist(*args, activerecord_strategies(**options), &block)
        end
        alias atomic_persist activerecord_atomic_persist

        # Called in the `after_commit` callback after finalization.
        def activerecord_persist
          activerecord_save
        end
        alias persist activerecord_persist

        private

        # Resolves strategies for atomic promotion and persistence.
        def activerecord_strategies(reload: :lock, persist: :save, **options)
          reload  = method(:"activerecord_#{reload}")  if reload.is_a?(Symbol)
          persist = method(:"activerecord_#{persist}") if persist.is_a?(Symbol)

          { reload: reload, persist: persist, **options }
        end

        # Implements the "fetch" reload strategy for #atomic_promote and
        # #atomic_persist.
        def activerecord_fetch
          yield record.clone.reload
        end

        # Implements the "lock" reload strategy for #atomic_promote and
        # #atomic_persist.
        def activerecord_lock
          record.transaction { yield record.clone.reload(lock: true) }
        end

        # Implements the "save" persist strategy for #atomic_promote and
        # #atomic_persist.
        def activerecord_save
          record.save(validate: false)
        end

        # ActiveRecord JSON column attribute needs to be assigned with a Hash.
        def serialize_column(data)
          activerecord_json_column? ? data : super
        end

        # Returns true if the data attribute represents a JSON or JSONB column.
        def activerecord_json_column?
          return false unless record.is_a?(ActiveRecord::Base)
          return false unless column = record.class.columns_hash[attribute.to_s]

          [:json, :jsonb].include?(column.type)
        end
      end
    end

    register_plugin(:activerecord, Activerecord)
  end
end
