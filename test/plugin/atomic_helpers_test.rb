require "test_helper"
require "shrine/plugins/atomic_helpers"

describe Shrine::Plugins::AtomicHelpers do
  before do
    @attacher = attacher { plugin :atomic_helpers }
    @shrine   = @attacher.shrine_class
  end

  describe "Attacher" do
    describe ".retrieve" do
      describe "for entities" do
        before do
          @shrine.plugin :entity

          @entity_class = entity_class(:file_data)
          @entity       = @entity_class.new
        end

        it "reads attacher attribute on an entity" do
          @entity_class.include @shrine::Attachment.new(:file, store: :other_store)

          attacher = @shrine::Attacher.retrieve(
            entity: @entity,
            name:   :file,
            data:   nil,
          )

          assert_equal @entity,      attacher.record
          assert_equal :file,        attacher.name
          assert_equal :other_store, attacher.store_key
        end

        it "forwards additional options to attacher attribute" do
          @entity_class.include @shrine::Attachment.new(:file, store: :other_store)

          attacher = @shrine::Attacher.retrieve(
            entity: @entity,
            name:   :file,
            data:   nil,
            cache:  :other_cache,
          )

          assert_equal :other_cache, attacher.cache_key
          assert_equal :other_store, attacher.store_key
        end

        it "creates entity attacher if attacher attribute is not defined" do
          attacher = @shrine::Attacher.retrieve(
            entity: @entity,
            name:   :file,
            data:   nil,
          )

          assert_instance_of @shrine::Attacher, attacher
          assert_equal @entity, attacher.record
          assert_equal :file,   attacher.name
          assert_equal :cache,  attacher.cache_key
          assert_equal :store,  attacher.store_key

          attacher.attach(fakeio)

          assert_nil @entity.file_data # entity attachers don't write
        end

        it "forwards additional options when creating attacher" do
          attacher = @shrine::Attacher.retrieve(
            entity: @entity,
            name:   :file,
            data:   nil,
            store:  :other_store,
          )

          assert_equal :other_store, attacher.store_key
        end

        it "asserts the attachment hasn't changed" do
          file    = @attacher.upload(fakeio)
          @entity = @entity_class.new(file_data: file.to_json)

          assert_instance_of @shrine::Attacher, @shrine::Attacher.retrieve(
            entity: @entity,
            name:   :file,
            data:   file.data,
          )

          assert_raises Shrine::AttachmentChanged do
            @shrine::Attacher.retrieve(
              entity: @entity,
              name:   :file,
              data:   nil,
            )
          end
        end
      end

      describe "for models" do
        before do
          @shrine.plugin :model

          @model_class = model_class(:file_data)
          @model       = @model_class.new
        end

        it "reads attacher attribute on a model" do
          @model_class.include @shrine::Attachment.new(:file, store: :other_store)

          attacher = @shrine::Attacher.retrieve(
            model: @model,
            name:  :file,
            data:  nil,
          )

          assert_equal @model,       attacher.record
          assert_equal :file,        attacher.name
          assert_equal :other_store, attacher.store_key
        end

        it "forwards additional options to attacher attribute" do
          @model_class.include @shrine::Attachment.new(:file, store: :other_store)

          attacher = @shrine::Attacher.retrieve(
            model: @model,
            name:  :file,
            data:  nil,
            cache: :other_cache,
          )

          assert_equal :other_cache, attacher.cache_key
          assert_equal :other_store, attacher.store_key
        end

        it "creates model attacher if attacher attribute is not defined" do
          attacher = @shrine::Attacher.retrieve(
            model: @model,
            name:  :file,
            data:  nil,
          )

          assert_instance_of @shrine::Attacher, attacher
          assert_equal @model, attacher.record
          assert_equal :file,  attacher.name
          assert_equal :cache, attacher.cache_key
          assert_equal :store, attacher.store_key

          attacher.attach(fakeio)

          assert_equal attacher.file.to_json, @model.file_data # model attachers write
        end

        it "forwards additional options when creating attacher" do
          attacher = @shrine::Attacher.retrieve(
            model: @model,
            name:  :file,
            data:  nil,
            store: :other_store,
          )

          assert_equal :other_store, attacher.store_key
        end

        it "asserts the attachment hasn't changed" do
          file   = @attacher.upload(fakeio)
          @model = @model_class.new(file_data: file.to_json)

          assert_instance_of @shrine::Attacher, @shrine::Attacher.retrieve(
            model: @model,
            name:  :file,
            data:  file.data,
          )

          assert_raises Shrine::AttachmentChanged do
            @shrine::Attacher.retrieve(
              model: @model,
              name:  :file,
              data:  nil,
            )
          end
        end
      end

      it "requires either entity or model to be passed in" do
        assert_raises ArgumentError do
          @shrine::Attacher.retrieve(
            name: :file,
            data: nil,
          )
        end
      end
    end

    describe "#abstract_atomic_promote" do
      # tested in activerecord & sequel plugin tests
    end

    describe "#abstract_atomic_persist" do
      # tested in activerecord & sequel plugin tests
    end
  end
end
