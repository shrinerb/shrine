require "test_helper"
require "tempfile"

class ProcessingTest < Minitest::Test
  def uploader(storage_key = :store, &processor)
    super(storage_key) do
      plugin :processing, versions: true, storage: :store, processor: processor
    end
  end

  test "processing into a single file" do
    @uploader = uploader { |io| FakeIO.new(io.read.reverse) }
    uploaded_file = @uploader.upload(fakeio("original"))

    assert_equal "lanigiro", uploaded_file.read
  end

  test "processing into versions" do
    @uploader = uploader { |io| Hash[processed: FakeIO.new(io.read.reverse)] }
    uploaded_file = @uploader.upload(fakeio("original"))

    assert_equal "lanigiro", uploaded_file["processed"].read
  end

  test "processed files are moved to the storage" do
    tempfile = Tempfile.new("")
    @uploader = uploader { |io| tempfile }
    @uploader.upload(fakeio)

    assert_equal nil, tempfile.path

    tempfile = Tempfile.new("")
    @uploader = uploader { |io| Hash[processed: tempfile] }
    @uploader.upload(fakeio)

    assert_equal nil, tempfile.path
  end

  test "only does processing on specified storage" do
    @uploader = uploader(:cache) { |io| FakeIO.new(io.read.reverse) }
    uploaded_file = @uploader.upload(fakeio("original"))

    assert_equal "original", uploaded_file.read
  end

  test "returning an invalid object" do
    @uploader = uploader { |io| "not an IO" }
    assert_raises(Shrine::InvalidFile) { @uploader.upload(fakeio) }

    @uploader = uploader { |io| Hash[original: "not an IO"] }
    assert_raises(Shrine::InvalidFile) { @uploader.upload(fakeio) }
  end

  test "uploaded files are downloaded before processing" do
    @uploader = uploader { |io| FakeIO.new(io.class.to_s) }
    uploaded_file = @uploader.class.new(:cache).upload(fakeio)

    processed_file = @uploader.upload(uploaded_file)

    assert_equal "Tempfile", processed_file.read
  end

  test "passing invalid options" do
    @uploader = uploader {}

    assert_raises(ArgumentError) do
      @uploader.class.plugin :processing, storage: :store, processor: "invalid"
    end

    assert_raises(Shrine::Error) do
      @uploader.class.plugin :processing, storage: :nonexistent, processor: ->{}
    end
  end
end
