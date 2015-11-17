require "test_helper"

describe "the default_url_options plugin" do
  def uploader(**options)
    super() { plugin :default_url_options, **options }
  end

  before do
    @uploader = uploader(store: {foo: "foo"})
    @uploader.storage.instance_eval do
      def url(id, **options)
        options
      end
    end
  end

  it "adds default options" do
    uploaded_file = @uploader.upload(fakeio)
    assert_equal Hash[foo: "foo"], uploaded_file.url
  end

  it "merges default options with custom options" do
    uploaded_file = @uploader.upload(fakeio)
    assert_equal Hash[foo: "foo", bar: "bar"], uploaded_file.url(bar: "bar")
  end

  it "allows custom options to override default options" do
    uploaded_file = @uploader.upload(fakeio)
    assert_equal Hash[foo: "bar"], uploaded_file.url(foo: "bar")
  end
end
