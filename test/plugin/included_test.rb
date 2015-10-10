require "test_helper"

describe "the included plugin" do
  def uploader(&block)
    super { plugin :included, &block }
  end

  it "enables extending the model attachment is being included to" do
    @uploader = uploader do |name|
      define_method("#{name}_foo") {}
    end

    model = Class.new
    model.include @uploader.class[:avatar]

    assert_respond_to model.new, :avatar_foo
  end
end
