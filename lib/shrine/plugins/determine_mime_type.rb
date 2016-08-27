class Shrine
  module Plugins
    # The `determine_mime_type` plugin stores the actual MIME type of the
    # uploaded file.
    #
    #     plugin :determine_mime_type
    #
    # By default the UNIX [file] utility is used to determine the MIME type, but
    # you can change it:
    #
    #     plugin :determine_mime_type, analyzer: :filemagic
    #
    # The plugin accepts the following analyzers:
    #
    # :file
    # : (Default). Uses the [file] utility to determine the MIME type from file
    #   contents. It is installed by default on most operating systems, but the
    #   [Windows equivalent] needs to be installed separately.
    #
    # :filemagic
    # : Uses the [ruby-filemagic] gem to determine the MIME type from file
    #   contents, using a similar MIME database as the `file` utility. Unlike
    #   the `file` utility, ruby-filemagic works on Windows without any setup.
    #
    # :mimemagic
    # : Uses the [mimemagic] gem to determine the MIME type from file contents.
    #   Unlike ruby-filemagic, mimemagic is a pure-ruby solution, so it will
    #   work across all Ruby implementations.
    #
    # :mime_types
    # : Uses the [mime-types] gem to determine the MIME type from the file
    #   *extension*. Note that unlike other solutions, this analyzer is not
    #   guaranteed to return the actual MIME type of the file.
    #
    # :default
    # : Uses the default way of extracting the MIME type, and that is from the
    #   "Content-Type" request header, which might not hold the actual MIME type
    #   of the file.
    #
    # Not all analyzers can recognize all types of files. For those cases you
    # can build your own analyzer, where you can reuse built-in analyzers:
    #
    #     plugin :determine_mime_type, analyzer: ->(io, analyzers) do
    #       analyzers[:mimemagic].call(io) || analyzers[:file].call(io)
    #     end
    #
    # [file]: http://linux.die.net/man/1/file
    # [Windows equivalent]: http://gnuwin32.sourceforge.net/packages/file.htm
    # [ruby-filemagic]: https://github.com/blackwinter/ruby-filemagic
    # [mimemagic]: https://github.com/minad/mimemagic
    # [mime-types]: https://github.com/mime-types/ruby-mime-types
    module DetermineMimeType
      def self.configure(uploader, opts = {})
        uploader.opts[:mime_type_analyzer] = opts.fetch(:analyzer, uploader.opts.fetch(:mime_type_analyzer, :file))
        uploader.opts[:mime_type_magic_header] = opts.fetch(:magic_header, uploader.opts.fetch(:mime_type_magic_header, MAGIC_NUMBER))
      end

      # How many bytes we need to read in order to determine the MIME type.
      MAGIC_NUMBER = 256 * 1024

      module InstanceMethods
        private

        # If a Shrine::UploadedFile was given, it returns its MIME type, since
        # that value was already determined by this analyzer. Otherwise it calls
        # a built-in analyzer or a custom one.
        def extract_mime_type(io)
          analyzer = opts[:mime_type_analyzer]
          return super if analyzer == :default

          analyzer = mime_type_analyzers[analyzer] if analyzer.is_a?(Symbol)
          args = [io, mime_type_analyzers].take(analyzer.arity.abs)

          mime_type = analyzer.call(*args)
          io.rewind

          mime_type
        end

        def mime_type_analyzers
          Hash.new { |hash, key| method(:"_extract_mime_type_with_#{key}") }
        end

        def _extract_mime_type_with_file(io)
          require "open3"

          cmd = ["file", "--mime-type", "--brief", "-"]
          options = {stdin_data: magic_header(io), binmode: true}

          begin
            stdout, stderr, status = Open3.capture3(*cmd, options)
          rescue Errno::ENOENT
            raise Error, "The `file` command-line tool is not installed"
          end

          raise Error, stderr unless status.success?
          $stderr.print(stderr)

          stdout.strip
        end

        def _extract_mime_type_with_mimemagic(io)
          require "mimemagic"

          mime = MimeMagic.by_magic(io)
          io.rewind

          mime.type if mime
        end

        def _extract_mime_type_with_filemagic(io)
          require "filemagic"

          filemagic = FileMagic.new(FileMagic::MAGIC_MIME_TYPE)
          mime_type = filemagic.buffer(magic_header(io))
          filemagic.close

          mime_type
        end

        def _extract_mime_type_with_mime_types(io)
          begin
            require "mime/types/columnar"
          rescue LoadError
            require "mime/types"
          end

          if filename = extract_filename(io)
            mime_type = MIME::Types.of(filename).first
            mime_type.to_s if mime_type
          end
        end

        def magic_header(io)
          content = io.read(opts[:mime_type_magic_header])
          io.rewind
          content
        end
      end
    end

    register_plugin(:determine_mime_type, DetermineMimeType)
  end
end
