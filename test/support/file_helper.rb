require "./test/support/fakeio"

module FileHelper
  extend self

  def fakeio(content = "file", **options)
    FakeIO.new(content, **options)
  end

  def image
    File.open("test/fixtures/image.jpg", binmode: true)
  end

  def tempfile(content, basename = "")
    tempfile = Tempfile.new(basename, binmode: true)
    tempfile.write(content)
    tempfile.tap(&:open)
  end
end

Minitest::Test.include FileHelper
