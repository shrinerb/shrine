require "test_helper"

class LocationTest < Minitest::Test
  def location_uploader(method_name = nil, &block)
    uploader(:bare) { plugin :location, generator: method_name || block }
  end

  test "generator is used for generating locations" do
    @uploader = location_uploader { |io, context| context[:foo] }
    uploaded_file = @uploader.upload(fakeio, foo: "foo")

    assert_equal "foo", uploaded_file.id
  end

  test "raises an error if string is not returned" do
    @uploader = location_uploader { |io, context| nil }

    assert_raises(Uploadie::Error) { @uploader.upload(fakeio, foo: "foo") }
  end

  test "allows the name of the method to be passed in" do
    @uploader = location_uploader(:location)
    def @uploader.location(io, context); context[:foo]; end

    uploaded_file = @uploader.upload(fakeio, foo: "foo")

    assert_equal "foo", uploaded_file.id
  end

  test "raises an error if processor is not a proc or a symbol" do
    assert_raises(ArgumentError) { location_uploader("invalid") }
  end
end
