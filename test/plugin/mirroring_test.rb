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

      it "doesn't mirror if :mirror is false" do
        file = @uploader.upload(fakeio, mirror: false)

        assert_equal :store, file.storage_key

        mirrored_file = @shrine.uploaded_file(id: file.id, storage: :other_store)

        refute mirrored_file.exists?
      end
    end
  end

  describe "UploadedFile" do
    before do
      @file          = @uploader.upload(fakeio("file"), mirror: false)
      @mirrored_file = @shrine.uploaded_file(id: @file.id, storage: :other_store)
    end

    describe "#trigger_mirror_upload" do
      it "uploads to mirror storages" do
        @file.trigger_mirror_upload

        assert @mirrored_file.exists?
      end

      it "calls mirror upload block" do
        @shrine.mirror_upload_block do |file|
          assert_instance_of @shrine::UploadedFile, file
          @job = Fiber.new { file.mirror_upload }
        end

        @file.trigger_mirror_upload

        refute @mirrored_file.exists?

        @job.resume

        assert @mirrored_file.exists?
      end

      it "skips mirroring if :upload is set to false" do
        @shrine.plugin :mirroring, upload: false

        @file.trigger_mirror_upload

        refute @mirrored_file.exists?
      end

      it "skips mirroring if no mirrors are defined" do
        @shrine.plugin :mirroring, mirror: {}

        @file.trigger_mirror_upload
      end
    end

    describe "#mirror_upload_background" do
      it "calls mirror upload block" do
        @shrine.mirror_upload_block do |file|
          assert_instance_of @shrine::UploadedFile, file
          @job = Fiber.new { file.mirror_upload }
        end

        @file.mirror_upload_background

        refute @mirrored_file.exists?

        @job.resume

        assert @mirrored_file.exists?
      end

      it "raises exception if mirror upload block is not registered" do
        assert_raises Shrine::Error do
          @file.mirror_upload_background
        end
      end
    end

    describe "#mirror_upload" do
      before do
        @shrine.plugin :mirroring, upload: false
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
        @file.mirror_upload
      end

      it "mirrors deletes" do
        @file.delete

        refute @mirrored_file.exists?
      end

      it "doesn't mirror if :mirror is false" do
        @file.delete(mirror: false)

        assert @mirrored_file.exists?
      end
    end

    describe "#trigger_mirror_delete" do
      before do
        @file.mirror_upload
      end

      it "mirrors deletes" do
        @file.trigger_mirror_delete

        refute @mirrored_file.exists?
      end

      it "calls mirror delete block" do
        @shrine.mirror_delete_block do |file|
          assert_instance_of @shrine::UploadedFile, file
          @job = Fiber.new { file.mirror_delete }
        end

        @file.trigger_mirror_delete

        assert @mirrored_file.exists?

        @job.resume

        refute @mirrored_file.exists?
      end

      it "skips mirroring if :delete is set to false" do
        @shrine.plugin :mirroring, delete: false

        @file.trigger_mirror_delete

        assert @mirrored_file.exists?
      end

      it "skips mirroring if no mirrors are defined" do
        @shrine.plugin :mirroring, mirror: {}

        @file.trigger_mirror_delete
      end
    end

    describe "#mirror_delete_background" do
      before do
        @file.mirror_upload
      end

      it "calls mirror delete block" do
        @shrine.mirror_delete_block do |file|
          assert_instance_of @shrine::UploadedFile, file
          @job = Fiber.new { file.mirror_delete }
        end

        @file.mirror_delete_background

        assert @mirrored_file.exists?

        @job.resume

        refute @mirrored_file.exists?
      end

      it "raises exception if mirror delete block is not registered" do
        assert_raises Shrine::Error do
          @file.mirror_delete_background
        end
      end
    end

    describe "#mirror_delete" do
      before do
        @file.mirror_upload
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
