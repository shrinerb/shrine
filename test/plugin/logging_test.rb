require "test_helper"
require "stringio"
require "logger"

describe "the logging plugin" do
  def uploader(**options)
    super() { plugin :logging, stream: $out, **options }
  end

  def capture
    yield
    result = $out.string
    $out.reopen(StringIO.new)
    result
  end

  before do
    $out = StringIO.new
    @context = {name: :avatar, phase: :store}
    @context[:record] = Object.const_set("User", Struct.new(:id)).new(16)
  end

  after do
    Object.send(:remove_const, "User")
  end

  it "logs processing" do
    @uploader = uploader

    stdout = capture { @uploader.upload(fakeio) }

    refute_match /PROCESS/, stdout

    @uploader.singleton_class.class_eval do
      def process(io, context = {})
        FakeIO.new(io.read.reverse)
      end
    end

    stdout = capture { @uploader.upload(fakeio) }

    assert_match /PROCESS \S+ 1 file \(0.0s\)$/, stdout
  end

  it "logs storing" do
    @uploader = uploader

    stdout = capture { @uploader.upload(fakeio) }

    assert_match /STORE \S+ 1 file \(0.0s\)$/, stdout
  end

  it "logs deleting" do
    @uploader = uploader
    uploaded_file = @uploader.upload(fakeio)

    stdout = capture { @uploader.delete(uploaded_file) }

    assert_match /DELETE \S+ 1 file \(0.0s\)$/, stdout
  end

  it "outputs context data" do
    @uploader = uploader

    @uploader.singleton_class.class_eval do
      def process(io, context = {})
        io
      end
    end

    stdout = capture do
      uploaded_file = @uploader.upload(fakeio, @context)
      @uploader.delete(uploaded_file, @context)
    end

    assert_match /PROCESS\[store\] \S+\[:avatar\] User\[16\] 1 file \(0.0s\)$/, stdout
    assert_match /STORE\[store\] \S+\[:avatar\] User\[16\] 1 file \(0.0s\)$/, stdout
    assert_match /DELETE\[store\] \S+\[:avatar\] User\[16\] 1 file \(0.0s\)$/, stdout
  end

  it "supports JSON format" do
    @uploader = uploader(format: :json)

    stdout = capture { @uploader.upload(fakeio, @context) }

    JSON.parse(stdout.match(/: /).post_match)
  end

  it "supports Heroku-style format" do
    @uploader = uploader(format: :heroku)

    stdout = capture { @uploader.upload(fakeio, @context) }

    assert_match "action=store phase=store", stdout
  end

  it "accepts a custom logger" do
    @uploader = uploader(logger: (logger = Logger.new(nil)))

    assert_equal logger, @uploader.class.logger
  end

  it "accepts model instances without an #id" do
    @uploader = uploader

    @context[:record].instance_eval { undef id }
    stdout = capture { @uploader.upload(fakeio, @context) }

    assert_match /STORE\[store\] \S+\[:avatar\] User 1 file \(0.0s\)$/, stdout
  end
end
