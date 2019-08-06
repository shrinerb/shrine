# frozen_string_literal: true

class Shrine
  class AttachmentChanged < Error
  end

  module Plugins
    class AtomicHelpers
      module AttacherClassMethods
        # Retrieves the attacher from the given entity/model and verifies that
        # the attachment hasn't changed. It raises `Shrine::AttachmentChanged`
        # exception if the attached file doesn't match.
        #
        #     Shrine::Attacher.retrieve(model: photo, name: :image, data: data)
        #     #=> #<ImageUploader::Attacher>
        def retrieve(model: nil, entity: nil, name:, data:, **options)
          fail ArgumentError, "either :model or :entity is required" unless model || entity

          record = model || entity

          attacher   = record.send(:"#{name}_attacher", **options) if record.respond_to?(:"#{name}_attacher")
          attacher ||= from_model(record, name, **options) if model
          attacher ||= from_entity(record, name, **options) if entity

          if attacher.file != from_data(data).file
            fail Shrine::AttachmentChanged, "attachment has changed"
          end

          attacher
        end
      end

      module AttacherMethods
        # Like #promote, but additionally persists the promoted file
        # atomically. You need to specify `:reload` and `:persist` strategies
        # when calling the method:
        #
        #     attacher.abstract_atomic_promote(
        #       reload:  reload_strategy,
        #       persist: persist_strategy,
        #     )
        #
        # This more convenient to use with ORM plugins, which provide defaults
        # for reloading and persistence.
        def abstract_atomic_promote(reload:, persist:, **options, &block)
          original_file = file

          result = promote(**options)

          begin
            abstract_atomic_persist(original_file, reload: reload, persist: persist, &block)
            result
          rescue Shrine::AttachmentChanged
            destroy
            raise
          end
        end

        # Reloads the record to check whether the attachment has changed. If it
        # hasn't, it persists the record. Otherwise it raises
        # `Shrine::AttachmentChanged` exception.
        #
        #     attacher.abstract_atomic_persist(
        #       reload:  reload_strategy,
        #       persist: persist_strategy,
        #     )
        #
        # This more convenient to use with ORM plugins, which provide defaults
        # for reloading and persistence.
        def abstract_atomic_persist(original_file = file, reload:, persist:)
          abstract_reload(reload) do |attacher|
            if attacher && attacher.file != original_file
              fail Shrine::AttachmentChanged, "attachment has changed"
            end

            yield attacher if block_given?

            abstract_persist(persist)
          end
        end

        protected

        # Calls the reload strategy and yields a reloaded attacher from the
        # reloaded record.
        def abstract_reload(strategy)
          return yield if strategy == false

          strategy.call do |record|
            reloaded_attacher = dup
            reloaded_attacher.load_entity(record, name)

            yield reloaded_attacher
          end
        end

        # Calls the persist strategy.
        def abstract_persist(strategy)
          return if strategy == false

          strategy.call
        end
      end
    end

    register_plugin(:atomic_helpers, AtomicHelpers)
  end
end
