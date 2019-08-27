require "test_helper"
require "shrine/plugins/default_storage"

describe Shrine::Plugins::DefaultStorage do
  before do
    @attacher = attacher { plugin :default_storage }
    @shrine   = @attacher.shrine_class
  end

  describe "Attacher" do
    [:cache, :store].each do |storage_key|
      describe "##{storage_key}_key" do
        it "returns static plugin setting" do
          @shrine.plugin :default_storage, storage_key => :"other_#{storage_key}"

          attacher = @shrine::Attacher.new

          assert_equal :"other_#{storage_key}", attacher.public_send(:"#{storage_key}_key")
        end

        it "returns static attacher setting" do
          @shrine.plugin :default_storage
          @shrine::Attacher.public_send(:"default_#{storage_key}", :"other_#{storage_key}")

          attacher = @shrine::Attacher.new

          assert_equal :"other_#{storage_key}", attacher.public_send(:"#{storage_key}_key")
        end

        it "returns dynamic plugin setting" do
          this = nil
          @shrine.plugin :default_storage, storage_key => -> {
            this = self
            :"other_#{storage_key}"
          }

          attacher = @shrine::Attacher.new

          assert_equal :"other_#{storage_key}", attacher.public_send(:"#{storage_key}_key")
          assert_equal attacher, this
        end

        it "returns dynamic attacher setting" do
          this = nil
          @shrine.plugin :default_storage
          @shrine::Attacher.public_send(:"default_#{storage_key}") do
            this = self
            :"other_#{storage_key}"
          end

          attacher = @shrine::Attacher.new

          assert_equal :"other_#{storage_key}", attacher.public_send(:"#{storage_key}_key")
          assert_equal attacher, this
        end

        it "returns deprecated dynamic plugin setting" do
          @shrine.plugin :entity
          @shrine.plugin :default_storage, storage_key => -> (record, name) {
            :"other_#{storage_key}"
          }

          attacher = @shrine::Attacher.new

          assert_equal :"other_#{storage_key}", attacher.public_send(:"#{storage_key}_key")
        end

        it "still allows overriding storage" do
          @shrine.plugin :default_storage, storage_key => :"other_#{storage_key}"

          attacher = @shrine::Attacher.new(storage_key => storage_key)

          assert_equal storage_key, attacher.public_send(:"#{storage_key}_key")
        end

        it "still returns default storage without settings" do
          assert_equal storage_key, @attacher.public_send(:"#{storage_key}_key")
        end
      end
    end
  end
end
