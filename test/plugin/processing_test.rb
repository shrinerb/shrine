require "test_helper"

class VersionsTest < Minitest::Test
  def uploader(storage: :store, **options, &processor)
    super(:bare) do
      plugin :processing, versions: true, storage: storage, processor: processor, **options
    end
  end

  def attacher(*args, &block)
    uploader = uploader(*args, &block)
    user = Struct.new(:avatar_data).new
    user.class.include uploader.class[:avatar]
    user.avatar_attacher
  end

  test "processing into a single file" do
    @uploader = uploader(storage: :cache) { |io| FakeIO.new(io.read.reverse) }

    cached, stored = cache_and_store(fakeio("original"))

    assert_kind_of Uploadie::UploadedFile, cached
    assert_equal :cache, cached.storage_key
    assert_equal "lanigiro", cached.read

    assert_kind_of Uploadie::UploadedFile, stored
    assert_equal :store, stored.storage_key
    assert_equal "lanigiro", stored.read

    @uploader = uploader(storage: :store) { |io| FakeIO.new(io.read.reverse) }

    cached, stored = cache_and_store(fakeio("original"))

    assert_kind_of Uploadie::UploadedFile, cached
    assert_equal :cache, cached.storage_key
    assert_equal "original", cached.read

    assert_kind_of Uploadie::UploadedFile, stored
    assert_equal :store, stored.storage_key
    assert_equal "lanigiro", stored.read
  end

  test "processing into multiple versions" do
    @uploader = uploader(storage: :cache) { |io| Hash[original: FakeIO.new(io.read.reverse)] }

    cached, stored = cache_and_store(fakeio("original"))

    assert_kind_of Uploadie::UploadedFile, cached[:original]
    assert_equal :cache, cached[:original].storage_key
    assert_equal "lanigiro", cached[:original].read

    assert_kind_of Uploadie::UploadedFile, stored[:original]
    assert_equal :store, stored[:original].storage_key
    assert_equal "lanigiro", stored[:original].read

    @uploader = uploader(storage: :store) { |io| Hash[original: FakeIO.new(io.read.reverse)] }

    cached, stored = cache_and_store(fakeio("original"))

    assert_kind_of Uploadie::UploadedFile, cached
    assert_equal :cache, cached.storage_key
    assert_equal "original", cached.read

    assert_kind_of Uploadie::UploadedFile, stored[:original]
    assert_equal :store, stored[:original].storage_key
    assert_equal "lanigiro", stored[:original].read
  end

  test "attachment workflow when generating versions on storing" do
    @attacher = attacher(storage: :store) { |io| Hash[thumb: io] }

    @attacher.set(fakeio)
    assert_kind_of Uploadie::UploadedFile, @attacher.get

    @attacher.save
    assert_kind_of Uploadie::UploadedFile, @attacher.get[:thumb]
    assert_equal :store, @attacher.get[:thumb].storage_key

    versions = @attacher.get
    @attacher.set(fakeio); @attacher.save
    refute_equal versions[:thumb].id, @attacher.get[:thumb].id
    refute versions[:thumb].exists?
  end

  test "attachment workflow when generating versions on caching" do
    @attacher = attacher(storage: :cache) { |io| Hash[thumb: io] }

    @attacher.set(fakeio)
    assert_kind_of Uploadie::UploadedFile, @attacher.get[:thumb]
    assert_equal :cache, @attacher.get[:thumb].storage_key

    @attacher.save
    assert_kind_of Uploadie::UploadedFile, @attacher.get[:thumb]
    assert_equal :store, @attacher.get[:thumb].storage_key

    versions = @attacher.get
    @attacher.set(fakeio); @attacher.save
    refute_equal versions[:thumb].id, @attacher.get[:thumb].id
    refute versions[:thumb].exists?
  end

  test "attachment url" do
    @attacher = attacher(storage: :cache) { |io| Hash[thumb: io] }
    @user = @attacher.record

    assert_equal nil, @user.avatar_url(:thumb)

    @user.avatar = fakeio

    refute_empty @user.avatar_url(:thumb)

    assert_raises(KeyError) { @user.avatar_url(:unknown) }
  end

  test "attachment url returns raw file URL if versions haven't been generated" do
    @attacher = attacher(storage: :store) { |io| Hash[thumb: io] }
    @user = @attacher.record

    assert_equal @user.avatar_url, @user.avatar_url(:thumb)
  end

  test "attachment url doesn't allow no argument when attachment is versioned" do
    @attacher = attacher(storage: :cache) { |io| Hash[thumb: io] }
    @user = @attacher.record

    @user.avatar = fakeio

    assert_raises(Uploadie::Error) { @user.avatar_url }
  end

  test "passes in version to the default url" do
    @attacher = attacher { |io| Hash[thumb: io] }
    uploader = @attacher.store
    def uploader.default_url(context); context[:version].to_s; end

    assert_equal "thumb", @attacher.record.avatar_url(:thumb)
  end

  test "returning an invalid object" do
    @uploader = uploader { |io| "not an IO" }

    assert_raises(Uploadie::InvalidFile) { @uploader.upload(fakeio) }

    @uploader = uploader { |io| Hash[original: "not an IO"] }

    assert_raises(Uploadie::InvalidFile) { @uploader.upload(fakeio) }
  end

  test "cached file is downloaded for processing" do
    @uploader = uploader(storage: :store) do |io|
      io.is_a?(Uploadie::UploadedFile) ? raise("io is not downloaded") : io
    end

    cached, stored = cache_and_store(fakeio)
  end

  test "doesn't allow validating versions" do
    @attacher = attacher(storage: :cache) { |io| Hash[thumb: io] }
    @attacher.set(fakeio)
    @attacher.uploadie_class.validate {}

    assert_raises(Uploadie::Error) { @attacher.valid? }
  end

  test "passing invalid options" do
    assert_raises(ArgumentError) { uploader(processor: "invalid") }
    assert_raises(IndexError) { uploader(storage: :nonexistent) {} }
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
