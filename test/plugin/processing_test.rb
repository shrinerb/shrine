require "test_helper"

class ProcessingTest < Minitest::Test
  def processing_uploader(storage: :store, **options, &processor)
    uploader(:bare) do
      plugin :processing, storage: storage, processor: processor, **options
    end
  end

  test "returning a hash of processed versions" do
    @uploader = processing_uploader { |io| Hash[original: FakeIO.new(io.read.reverse)] }

    versions = @uploader.upload(fakeio("original"))

    assert_kind_of Uploadie::UploadedFile, versions[:original]
    assert_equal "lanigiro", versions[:original].read
  end

  test "ruturning a single processed file" do
    @uploader = processing_uploader { |io| FakeIO.new(io.read.reverse) }

    processed = @uploader.upload(fakeio("original"))

    assert_kind_of Uploadie::UploadedFile, processed
    assert_equal "lanigiro", processed.read
  end

  test "returning an invalid object" do
    @uploader = processing_uploader { |io| "not an IO" }

    assert_raises(Uploadie::InvalidFile) { @uploader.upload(fakeio) }

    @uploader = processing_uploader { |io| Hash[original: "not an IO"] }

    assert_raises(Uploadie::InvalidFile) { @uploader.upload(fakeio) }
  end

  test "processing on caching" do
    @uploader = processing_uploader(storage: :cache) { |io| Hash[original: FakeIO.new(io.read.reverse)] }

    cached, stored = cache_and_store(fakeio("original"))

    assert_kind_of Uploadie::UploadedFile, cached[:original]
    assert_equal "lanigiro", cached[:original].read

    assert_kind_of Uploadie::UploadedFile, stored[:original]
    assert_equal "lanigiro", stored[:original].read


    @uploader = processing_uploader(storage: :cache) { |io| FakeIO.new(io.read.reverse) }

    cached, stored = cache_and_store(fakeio("original"))

    assert_kind_of Uploadie::UploadedFile, cached
    assert_equal "lanigiro", cached.read

    assert_kind_of Uploadie::UploadedFile, stored
    assert_equal "lanigiro", stored.read
  end

  test "processing on storing" do
    @uploader = processing_uploader(storage: :store) { |io| Hash[original: FakeIO.new(io.read.reverse)] }

    cached, stored = cache_and_store(fakeio("original"))

    assert_kind_of Uploadie::UploadedFile, cached
    assert_equal "original", cached.read

    assert_kind_of Uploadie::UploadedFile, stored[:original]
    assert_equal "lanigiro", stored[:original].read


    @uploader = processing_uploader(storage: :store) { |io| FakeIO.new(io.read.reverse) }

    cached, stored = cache_and_store(fakeio("original"))

    assert_kind_of Uploadie::UploadedFile, cached
    assert_equal "original", cached.read

    assert_kind_of Uploadie::UploadedFile, stored
    assert_equal "lanigiro", stored.read
  end

  test "cached file is downloaded for processing" do
    @uploader = processing_uploader(storage: :store) do |io|
      io.is_a?(Uploadie::UploadedFile) ? raise("io is not downloaded") : io
    end

    cached, stored = cache_and_store(fakeio)
  end

  test "passing symbol :processor" do
    @uploader = processing_uploader(processor: :process)
    def @uploader.process(io, context); FakeIO.new(io.read.reverse); end

    uploaded_file = @uploader.upload(fakeio("file"))

    assert_equal "elif", uploaded_file.read
  end

  test "passing invalid options" do
    assert_raises(ArgumentError) { processing_uploader(processor: "invalid") }
    assert_raises(IndexError) { processing_uploader(storage: :nonexistent) {} }
  end

  private

  def cache_and_store(io)
    cache = @uploader.class.new(:cache)
    store = @uploader.class.new(:store)

    cached = cache.upload(io)
    stored = store.upload(cached)

    [cached, stored]
  end
end
