require "test_helper"

class DefaultUrlTest < Minitest::Test
  def default_url_attacher(method_name = nil, &block)
    @uploader = uploader(:bare) { plugin :default_url, generator: method_name || block }
    @user = Struct.new(:avatar_data).new
    @uploader.class::Attacher.new(@user, :avatar)
  end

  test "generator is called when URL is nil" do
    @attacher = default_url_attacher { |context| (context[:version] || "default").to_s }

    assert_equal "default", @attacher.url
    assert_equal "small", @attacher.url(:small)
  end

  test "allows the name of the method to be passed in" do
    @attacher = default_url_attacher(:default_url)
    uploader = @attacher.store
    def uploader.default_url(context); "#{context[:name]}_default"; end

    assert_equal "avatar_default", @attacher.url
  end

  test "raises an error if processor is not a proc or a symbol" do
    assert_raises(ArgumentError) { default_url_attacher("invalid") }
  end
end
