require "test_helper"
require "shrine/plugins/mirroring"

describe Shrine::Plugins::Mirroring do
  before do
    @shrine   = shrine { plugin :mirroring, mirror: { store: :other_store } }
    @uploader = @shrine.new(:store)
  end

  describe "Shrine" do
    describe "#upload" do
      it "mirrors uploads" do
        file = @uploader.upload(fakeio)

        assert_equal :store, file.storage_key

        mirrored_file = @shrine.uploaded_file(id: file.id, storage: :other_store)

        assert mirrored_file.exists?
      end

      it "uses custom mirroring block" do
        block_called = false
        @shrine.mirror_upload do |uploaded_file|
          assert_instance_of @shrine::UploadedFile, uploaded_file
          block_called = true
        end

        file = @uploader.upload(fakeio)

        assert block_called

        mirrored_file = @shrine.uploaded_file(id: file.id, storage: :other_store)

        refute mirrored_file.exists?
      end

      it "allows disabling mirroring" do
        @shrine.plugin :mirroring, upload: false

        file = @uploader.upload(fakeio)

        mirrored_file = @shrine.uploaded_file(id: file.id, storage: :other_store)

        refute mirrored_file.exists?
      end

      it "handles no mirroring" do
        @shrine.plugin :mirroring, mirror: {}

        @uploader.upload(fakeio)
      end
    end
  end

  describe "UploadedFile" do
    describe "#mirror_upload" do
      before do
        @shrine.plugin :mirroring, upload: false

        @file          = @uploader.upload(fakeio("file"))
        @mirrored_file = @shrine.uploaded_file(id: @file.id, storage: :other_store)
      end

      it "uploads to mirror storages" do
        @file.mirror_upload

        assert @mirrored_file.exists?
        assert_equal "file", @mirrored_file.read
      end

      it "returns mirrored files" do
        files = @file.mirror_upload

        assert_equal [@mirrored_file], files
      end

      it "handles mirroring to multiple storages" do
        @shrine.plugin :mirroring, mirror: { store: [:other_store, :other_store] }

        @file.mirror_upload

        assert @mirrored_file.exists?
        assert_equal "file", @mirrored_file.read
      end

      it "opens the source file only once" do
        @shrine.plugin :mirroring, mirror: { store: [:other_store, :other_store] }

        @file.storage.expects(:open).once.returns(StringIO.new("file"))

        @file.mirror_upload
      end

      it "doesn't open the source file if not required" do
        @shrine.plugin :mirroring, mirror: { store: [:other_store, :other_store] }

        @shrine.storages[:other_store].instance_eval do
          def upload(io, id, **)
            # doesn't read the source file
          end
        end

        @file.storage.expects(:open).never

        @file.mirror_upload
      end

      it "closes the source file" do
        @file.mirror_upload

        refute @file.opened?
      end

      it "doesn't close the source file if user opened it" do
        @file.open do
          @file.mirror_upload

          assert @file.opened?
          refute @file.to_io.closed?
        end
      end

      it "raises exception when mirrors not registered" do
        @shrine.plugin :mirroring, mirror: {}

        assert_raises Shrine::Error do
          @file.mirror_upload
        end
      end
    end

    describe "#delete" do
      before do
        @file          = @uploader.upload(fakeio)
        @mirrored_file = @shrine.uploaded_file(id: @file.id, storage: :other_store)
      end

      it "mirrors deletes" do
        @file.delete

        refute @mirrored_file.exists?
      end

      it "uses custom mirroring block" do
        block_called = false
        @shrine.mirror_delete do |uploaded_file|
          assert_instance_of @shrine::UploadedFile, uploaded_file
          block_called = true
        end

        @file.delete

        assert block_called

        assert @mirrored_file.exists?
      end

      it "allows disabling mirroring" do
        @shrine.plugin :mirroring, delete: false

        @file.delete

        assert @mirrored_file.exists?
      end

      it "handles no mirroring" do
        @shrine.plugin :mirroring, mirror: {}

        @file.delete
      end
    end

    describe "#mirror_delete" do
      before do
        @shrine.plugin :mirroring, delete: false

        @file          = @uploader.upload(fakeio("file"))
        @mirrored_file = @shrine.uploaded_file(id: @file.id, storage: :other_store)
      end

      it "deletes from mirror storages" do
        @file.mirror_delete

        refute @mirrored_file.exists?
      end

      it "raises exception when mirrors not registered" do
        @shrine.plugin :mirroring, mirror: {}

        assert_raises Shrine::Error do
          @file.mirror_delete
        end
      end
    end
  end
end
