require "minitest/hooks/default"
require "./test/support/fakeio"
require "./test/support/test_storage"

class Minitest::HooksSpec
  def uploader(storage_key = :store, &block)
    uploader_class = Class.new(Shrine)
    uploader_class.storages[:cache] = Shrine::Storage::Test.new
    uploader_class.storages[:store] = Shrine::Storage::Test.new
    uploader_class.class_eval(&block) if block
    uploader_class.new(storage_key)
  end

  def attacher(*args, attachment_options: {}, &block)
    uploader = uploader(*args, &block)
    Object.send(:remove_const, "User") if defined?(User) # for warnings
    user_class = Object.const_set("User", Struct.new(:avatar_data, :id))
    user_class.include uploader.class::Attachment.new(:avatar, attachment_options)
    user_class.new.avatar_attacher
  end

  def teardown
    super
    Object.send(:remove_const, "User") if defined?(User)
  end

  def fakeio(content = "file", **options)
    FakeIO.new(content, **options)
  end

  def image
    File.open("test/fixtures/image.jpg", "rb")
  end

  def io?(object)
    missing_methods = %i[read rewind eof? close size].reject do |m, a|
      object.respond_to?(m) && [a.count, -1].include?(object.method(m).arity)
    end
    missing_methods.empty?
  end
end
