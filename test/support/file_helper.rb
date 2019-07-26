require "./test/support/fakeio"

module Support
  module FileHelper
    def fakeio(content = "file", **options)
      FakeIO.new(content, **options)
    end

    def image
      File.open("test/fixtures/image.jpg", binmode: true)
    end

    def io?(object)
      missing_methods = %i[read rewind eof? close size].select { |m| !object.respond_to?(m) }
      missing_methods.empty?
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
