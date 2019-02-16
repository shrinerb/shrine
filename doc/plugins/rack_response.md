# Rack Response

The [`rack_response`][rack_response] plugin allows you to convert an
`UploadedFile` object into a triple consisting of status, headers, and body,
suitable for returning as a response in a Rack-based application.

```rb
plugin :rack_response
```

To convert a `Shrine::UploadedFile` into a Rack response, simply call
`#to_rack_response`:

```rb
status, headers, body = uploaded_file.to_rack_response
status  #=> 200
headers #=>
# {
#   "Content-Length"      => "100",
#   "Content-Type"        => "text/plain",
#   "Content-Disposition" => "inline; filename=\"file.txt\"",
#   "Accept-Ranges"       => "bytes"
# }
body    # object that responds to #each and #close
```

An example how this can be used in a Rails controller:

```rb
class FilesController < ActionController::Base
  def download
    # ...
    set_rack_response record.attachment.to_rack_response
  end

  private

  def set_rack_response((status, headers, body))
    self.status = status
    self.headers.merge!(headers)
    self.response_body = body
  end
end
```

The `#each` method on the response body object will stream the uploaded file
directly from the storage. It also works with [Rack::Sendfile] when using
`FileSystem` storage.

## Type

The response `Content-Type` header will default to the value of the `mime_type`
metadata. A custom content type can be provided via the `:type` option:

```rb
response = uploaded_file.to_rack_response(type: "text/plain; charset=utf-8")
response[1]["Content-Type"] #=> "text/plain; charset=utf-8"
```

## Filename

The download filename in the `Content-Disposition` header will default to the
value of the `filename` metadata. A custom download filename can be provided
via the `:filename` option:

```rb
response = uploaded_file.to_rack_response(filename: "my-filename.txt")
response[1]["Content-Disposition"] #=> "inline; filename=\"my-filename.txt\""
```

## Disposition

The default disposition in the "Content-Disposition" header is `inline`, but it
can be changed via the `:disposition` option:

```rb
response = uploaded_file.to_rack_response(disposition: "attachment")
response[1]["Content-Disposition"] #=> "attachment; filename=\"file.txt\""
```

## Range

[Partial responses][range requests] are also supported via the `:range` option,
which accepts a value of the `Range` request header.

```rb
status, headers, body = uploaded_file.to_rack_response(range: env["HTTP_RANGE"])
status                    #=> 206
headers["Content-Length"] #=> "101"
headers["Content-Range"]  #=> "bytes 100-200/1000"
body                      # partial content
```

## Download options

The `#to_rack_response` method will automatically open the `UploadedFile` if it
hasn't been opened yet. If you want to pass additional download options to the
storage, you can explicitly call `UploadedFile#open` beforehand:

```rb
uploaded_file.open(
  sse_customer_algorithm: "AES256",
  sse_customer_key:       "secret_key",
  sse_customer_key_md5:   "secret_key_md5",
)

uploaded_file.to_rack_response
```

[rack_response]: /lib/shrine/plugins/rack_response.rb
[range requests]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Range_requests
[Rack::Sendfile]: https://www.rubydoc.info/github/rack/rack/Rack/Sendfile
