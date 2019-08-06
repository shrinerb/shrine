require "./test/support/fakeio"

module Support
  module FileHelper
    def fakeio(content = "file", **options)
      FakeIO.new(content, **options)
    end

    def image
      File.open("test/fixtures/image.jpg", binmode: true)
    end

    def tempfile(content, basename = "")
      tempfile = Tempfile.new(basename, binmode: true)
      tempfile.write(content)
      tempfile.rewind
      tempfile
    end
  end
end

Minitest::Test.include Support::FileHelper
