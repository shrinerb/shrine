# Determine MIME Type

The `determine_mime_type` plugin allows you to determine and store the actual
MIME type of the file analyzed from file content.

```rb
plugin :determine_mime_type
```

By default the UNIX [file] utility is used to determine the MIME type, and the
result is automatically written to the `mime_type` metadata field. You can
choose a different built-in MIME type analyzer:

```rb
plugin :determine_mime_type, analyzer: :marcel
```

The following analyzers are accepted:

| Name            | Description                                                                                                                                                                                                                                                                       |
| :------         | :-----------                                                                                                                                                                                                                                                                      |
| `:file`         | (Default). Uses the [file] utility to determine the MIME type from file contents. It is installed by default on most operating systems, but the [Windows equivalent] needs to be installed separately.                                                                            |
| `:fastimage`    | Uses the [fastimage] gem to determine the MIME type from file contents. Fastimage is optimized for speed over accuracy. Best used for image content.                                                                                                                              |
| `:filemagic`    | Uses the [ruby-filemagic] gem to determine the MIME type from file contents, using a similar MIME database as the `file` utility. Unlike the `file` utility, ruby-filemagic works on Windows without any setup.                                                                   |
| `:mimemagic`    | Uses the [mimemagic] gem to determine the MIME type from file contents. Unlike ruby-filemagic, mimemagic is a pure-ruby solution, so it will work across all Ruby implementations.                                                                                                |
| `:marcel`       | Uses the [marcel] gem to determine the MIME type from file contents. Marcel is Basecamp's wrapper around mimemagic, it adds priority logic (preferring magic over name when given both), some extra type definitions, and common type subclasses (including Keynote, Pages, etc). |
| `:mime_types`   | Uses the [mime-types] gem to determine the MIME type from the file extension. Note that unlike other solutions, this analyzer is not guaranteed to return the actual MIME type of the file.                                                                                       |
| `:mini_mime`    | Uses the [mini_mime] gem to determine the MIME type from the file extension. Note that unlike other solutions, this analyzer is not guaranteed to return the actual MIME type of the file.                                                                                        |
| `:content_type` | Retrieves the value of the `#content_type` attribute of the IO object. Note that this value normally comes from the "Content-Type" request header, so it's not guaranteed to hold the actual MIME type of the file.                                                               |

A single analyzer is not going to properly recognize all types of files, so you
can build your own custom analyzer for your requirements, where you can combine
the built-in analyzers. For example, if you want to correctly determine MIME
type of .css, .js, .json, .csv, .xml, or similar text-based files, you can
combine `file` and `mime_types` analyzers:

```rb
plugin :determine_mime_type, analyzer: -> (io, analyzers) do
  mime_type = analyzers[:file].call(io)
  mime_type = analyzers[:mime_types].call(io) if mime_type == "text/plain"
  mime_type
end
```

You can also use methods for determining the MIME type directly:

```rb
# or YourUploader.determine_mime_type(io)
Shrine.determine_mime_type(io) # calls the defined analyzer
#=> "image/jpeg"

# or YourUploader.mime_type_analyzers
Shrine.mime_type_analyzers[:file].call(io) # calls a built-in analyzer
#=> "image/jpeg"
```

[file]: http://linux.die.net/man/1/file
[Windows equivalent]: http://gnuwin32.sourceforge.net/packages/file.htm
[ruby-filemagic]: https://github.com/blackwinter/ruby-filemagic
[mimemagic]: https://github.com/minad/mimemagic
[marcel]: https://github.com/basecamp/marcel
[mime-types]: https://github.com/mime-types/ruby-mime-types
[mini_mime]: https://github.com/discourse/mini_mime
[fastimage]: https://github.com/sdsykes/fastimage
