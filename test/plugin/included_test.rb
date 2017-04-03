require "test_helper"
require "shrine/plugins/included"

describe Shrine::Plugins::Included do
  it "enables extending the model attachment is being included to" do
    @uploader = uploader do
      plugin :included do |name|
        define_method("#{name}_foo") {}
      end
    end

    model = Class.new
    model.include @uploader.class::Attachment.new(:avatar)
    assert_respond_to model.new, :avatar_foo
  end
end
