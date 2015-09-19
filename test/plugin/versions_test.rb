require "test_helper"

class VersionsTest < Minitest::Test
  def setup
    @attacher = attacher { plugin :_versions, names: [:thumb] }
    @uploader = @attacher.store
  end

  test "allows uploading versions" do
    versions = @uploader.upload(thumb: fakeio)

    assert_kind_of Shrine::UploadedFile, versions.fetch("thumb")
  end

  test "passes the version name to location generator" do
    @uploader.class.class_eval do
      def generate_location(io, version:)
        version.to_s
      end
    end
    versions = @uploader.upload(thumb: fakeio)

    assert_equal "thumb", versions.fetch("thumb").id
  end

  test "works with the rack_file plugin" do
    @uploader = uploader do
      plugin :rack_file
      plugin :_versions, names: [:thumb]
    end

    uploaded_file = @uploader.upload(tempfile: fakeio)

    assert_kind_of Shrine::UploadedFile, uploaded_file
  end

  test "overrides #uploaded?" do
    versions = @uploader.upload(thumb: fakeio)

    assert @uploader.uploaded?(versions)
  end

  test "attachment url accepts a version name" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    assert_equal uploaded_file.url, @attacher.url(:thumb)
  end

  test "attachment url returns nil when a attachment doesn't exist" do
    assert_equal nil, @attacher.url(:thumb)
  end

  test "attachment url fails explicity when version doesn't exist" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    assert_raises(KeyError) { @attacher.url(:unknown) }
  end

  test "attachment url returns raw file URL if versions haven't been generated" do
    @attacher.set(fakeio)

    assert_equal @attacher.url, @attacher.url(:thumb)
  end

  test "attachment url doesn't allow no argument when attachment is versioned" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    assert_raises(Shrine::Error) { @attacher.url }
  end

  test "passes in :version to the default url" do
    @uploader.class.class_eval do
      def default_url(context)
        context.fetch(:version).to_s
      end
    end

    assert_equal "thumb", @attacher.url(:thumb)
  end

  test "doesn't allow validating versions" do
    @uploader.class.validate {}
    uploaded_file = @uploader.upload(fakeio)

    assert_raises(Shrine::Error) { @attacher.set("thumb" => uploaded_file.data) }
  end

  test "attacher returns a hash of versions" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    assert_kind_of Shrine::UploadedFile, @attacher.get.fetch("thumb")
  end

  test "attacher destroys versions successfully" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    @attacher.destroy

    refute uploaded_file.exists?
  end

  test "attacher replaces versions sucessfully" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    @attacher.set("thumb" => @uploader.upload(fakeio).data)
    @attacher.save

    refute uploaded_file.exists?
  end

  test "attacher filters the hash to only registered version" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data, "malicious" => uploaded_file.data)

    assert_equal ["thumb"], @attacher.get.keys
  end
end
