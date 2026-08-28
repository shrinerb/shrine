require "test_helper"
require "shrine/plugins/fallback_storage"

describe Shrine::Plugins::FallbackStorage do
  before do
    @shrine = shrine { plugin :fallback_storage, store: :other_store }
    @uploader = @shrine.new(:store)
  end

  describe "Shrine" do
    describe ".plugin" do
      it "raises Shrine::MissingStorage if fallback storage not exists" do
        assert_raises Shrine::MissingStorage do
          shrine { plugin :fallback_storage, store: :not_exists }
        end
      end
    end

    describe "#upload" do
      it "not upload to fallback storage" do
        file = @uploader.upload(fakeio)

        assert_equal :store, file.storage_key
        refute @shrine.storages[:other_store].exists?(file.id)
      end
    end
  end

  describe "UploadedFile" do
    describe "#exists?" do
      it "exists in primary storage" do
        file = @uploader.upload(fakeio)

        assert file.exists?
        refute @shrine.storages[:other_store].exists?(file.id)
        assert @uploader.storage.exists?(file.id)
      end

      it "exists in fallback storage" do
        id = SecureRandom.hex
        @shrine.storages[:other_store].upload(fakeio, id)
        file = @shrine.uploaded_file({ "id" => id, "storage" => "store" })

        assert file.exists?
        assert @shrine.storages[:other_store].exists?(file.id)
        refute @uploader.storage.exists?(file.id)
      end

      it "exists in both storages" do
        id = SecureRandom.hex
        @shrine.storages[:store].upload(fakeio("primary"), id)
        @shrine.storages[:other_store].upload(fakeio("fallback"), id)
        file = @shrine.uploaded_file({ "id" => id, "storage" => "store" })

        assert file.exists?
        assert_equal "primary", file.read
      end

      it "not exists in both storages" do
        file = @shrine.uploaded_file({ "id" => SecureRandom.hex, "storage" => "store" })

        refute file.exists?
        refute @shrine.storages[:other_store].exists?(file.id)
        refute @uploader.storage.exists?(file.id)
      end
    end

    describe "#delete" do
      it "delete only from primary storage" do
        id = SecureRandom.hex
        @shrine.storages[:store].upload(fakeio("primary"), id)
        @shrine.storages[:other_store].upload(fakeio("fallback"), id)
        file = @shrine.uploaded_file({ "id" => id, "storage" => "store" })
        file.delete

        assert file.exists?
        assert_equal "fallback", file.read

        file = @shrine.uploaded_file({ "id" => id, "storage" => "store" })
        file.delete

        assert file.exists?
        assert_equal "fallback", file.read
      end
    end

    describe "#replace" do
      it "replace only from primary storage" do
        id = SecureRandom.hex
        @shrine.storages[:store].upload(fakeio("primary"), id)
        @shrine.storages[:other_store].upload(fakeio("fallback"), id)
        file = @shrine.uploaded_file({ "id" => id, "storage" => "store" })
        file.replace(fakeio("primary2"))

        assert file.exists?
        assert_equal "primary2", file.read
        assert_equal "fallback", @shrine.storages[:other_store].open(id).read
      end
    end
  end
end
