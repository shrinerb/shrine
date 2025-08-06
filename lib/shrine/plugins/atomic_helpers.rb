# frozen_string_literal: true

class Shrine
  class AttachmentChanged < Error
  end

  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/atomic_helpers
    class AtomicHelpers
      module AttacherClassMethods
        # Retrieves the attacher from the given entity/model and verifies that
        # the attachment hasn't changed. It raises `Shrine::AttachmentChanged`
        # exception if the attached file doesn't match.
        #
        #     Shrine::Attacher.retrieve(model: photo, name: :image, file: file_data)
        #     #=> #<ImageUploader::Attacher>
        def retrieve(model: nil, entity: nil, name:, file:, **options)
          fail ArgumentError, "either :model or :entity is required" unless model || entity

          record = model || entity

          attacher   = record.send(:"#{name}_attacher", **options) if record.respond_to?(:"#{name}_attacher")
          attacher ||= from_model(record, name, **options) if model
          attacher ||= from_entity(record, name, **options) if entity

          if attacher.file != attacher.uploaded_file(file)
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
        # This more convenient to use with concrete persistence plugins, which
        # provide defaults for reloading and persistence.
        def abstract_atomic_promote(reload:, persist:, **options, &block)
          original_file = file

          result = promote(**options)

          begin
            abstract_atomic_persist(original_file, reload: reload, persist: persist, &block)
            result
          rescue Shrine::AttachmentChanged
            destroy_attached
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
        # This more convenient to use with concrete persistence plugins, which
        # provide defaults for reloading and persistence.
        def abstract_atomic_persist(original_file = file, reload:, persist:)
          abstract_reload(reload) do |attacher|
            if attacher && attacher.file != original_file
              fail Shrine::AttachmentChanged, "attachment has changed"
            end

            yield attacher if block_given?

            if attacher
              attacher.abstract_persist(persist)
            else
              abstract_persist(persist)
            end
          end
        end

        # Return only needed main file data, without the metadata. This allows
        # you to avoid bloating your background job payload when you have
        # derivatives or lots of metadata, by only sending data you need for
        # atomic persitence.
        #
        #     attacher.file_data #=> { "id" => "abc123.jpg", "storage" => "store" }
        def file_data
          file!.data.reject { |key, _| key == "metadata" }
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
