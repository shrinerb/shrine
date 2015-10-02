require "test_helper"
require "stringio"

describe "logging plugin" do
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
  end

  it "logs processing" do
    @uploader = uploader

    stdout = capture { @uploader.upload(fakeio) }

    refute_match /PROCESS/, stdout

    @uploader.class.plugin :versions, names: [:original, :reverse]
    @uploader.singleton_class.class_eval do
      def process(io, context = {})
        {original: io, reverse: FakeIO.new(io.read.reverse)}
      end
    end

    stdout = capture { @uploader.upload(fakeio) }

    assert_match /PROCESS \S+ 1 file => 2 files \(0.00s\)$/, stdout
  end

  it "logs storing" do
    @uploader = uploader

    stdout = capture { @uploader.upload(fakeio) }

    assert_match /STORE \S+ 1 file \(0.00s\)$/, stdout
  end

  it "logs deleting" do
    @uploader = uploader
    uploaded_file = @uploader.upload(fakeio)

    stdout = capture { @uploader.delete(uploaded_file) }

    assert_match /DELETE \S+ 1 file \(0.00s\)$/, stdout
  end

  it "outputs :phase and :name" do
    @uploader = uploader

    @uploader.singleton_class.class_eval do
      def process(io, context = {})
        io
      end
    end

    stdout = capture do
      uploaded_file = @uploader.upload(fakeio, name: :avatar, phase: :endpoint)
      @uploader.delete(uploaded_file, name: :avatar, phase: :destroy)
    end

    assert_match /PROCESS\[endpoint\] \S+\[:avatar\] 1 file => 1 file \(0.00s\)$/, stdout
    assert_match /STORE\[endpoint\] \S+\[:avatar\] 1 file \(0.00s\)$/, stdout
    assert_match /DELETE\[destroy\] \S+\[:avatar\] 1 file \(0.00s\)$/, stdout
  end
end
