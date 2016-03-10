require "test_helper"
require "stringio"
require "logger"

describe "the logging plugin" do
  def capture
    yield
    result = $out.string
    $out.reopen(StringIO.new)
    result
  end

  before do
    $out = StringIO.new
    @uploader = uploader { plugin :logging, stream: $out }
    @context = {name: :avatar, phase: :store}
    @context[:record] = Object.const_set("User", Struct.new(:id)).new(16)
  end

  after do
    Object.send(:remove_const, "User")
  end

  it "logs processing" do
    stdout = capture { @uploader.upload(fakeio) }
    refute_match /PROCESS/, stdout

    @uploader.instance_eval { def process(io, context); io; end }
    stdout = capture { @uploader.upload(fakeio) }
    assert_match /PROCESS \S+ 1 file \(\d+\.\d+s\)$/, stdout
  end

  it "logs storing" do
    stdout = capture { @uploader.upload(fakeio) }
    assert_match /STORE \S+ 1 file \(\d+\.\d+s\)$/, stdout
  end

  it "logs deleting" do
    uploaded_file = @uploader.upload(fakeio)
    stdout = capture { @uploader.delete(uploaded_file) }
    assert_match /DELETE \S+ 1 file \(\d+\.\d+s\)$/, stdout
  end

  it "outputs context data" do
    @uploader.instance_eval { def process(io, context); io; end }

    stdout = capture do
      uploaded_file = @uploader.upload(fakeio, @context)
      @uploader.delete(uploaded_file, @context)
    end

    assert_match /PROCESS\[store\] \S+\[:avatar\] User\[16\] 1 file \(\d+\.\d+s\)$/, stdout
    assert_match /STORE\[store\] \S+\[:avatar\] User\[16\] 1 file \(\d+\.\d+s\)$/, stdout
    assert_match /DELETE\[store\] \S+\[:avatar\] User\[16\] 1 file \(\d+\.\d+s\)$/, stdout
  end

  it "supports JSON format" do
    @uploader.opts[:logging_format] = :json
    stdout = capture { @uploader.upload(fakeio, @context) }
    JSON.parse(stdout[/\{.+\}/])
  end

  it "supports Heroku-style format" do
    @uploader.opts[:logging_format] = :heroku
    stdout = capture { @uploader.upload(fakeio, @context) }
    assert_match "action=store phase=store", stdout
  end

  it "accepts a custom logger" do
    @uploader.class.logger = (logger = Logger.new(nil))
    assert_equal logger, @uploader.class.logger
  end

  it "accepts model instances without an #id" do
    @context[:record].instance_eval { undef id }
    stdout = capture { @uploader.upload(fakeio, @context) }
    assert_match /STORE\[store\] \S+\[:avatar\] User 1 file \(\d+\.\d+s\)$/, stdout
  end
end
