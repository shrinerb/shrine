# Rack File

The `rack_file` plugin enables uploaders to accept Rack uploaded file hashes
for uploading.

```rb
plugin :rack_file
```

When a file is uploaded to your Rack application using the
`multipart/form-data` parameter encoding, Rack converts the uploaded file to a
hash.

```rb
file_hash #=>
# {
#   :name => "file",
#   :filename => "cats.png",
#   :type => "image/png",
#   :tempfile => #<Tempfile:/var/folders/3n/3asd/-Tmp-/RackMultipart201-1476-nfw2-0>,
#   :head => "Content-Disposition: form-data; ...",
# }
```

Since Shrine only accepts IO objects, you would normally need to fetch the
`:tempfile` object and pass it directly. This plugin enables the attacher to
accept the Rack uploaded file hash directly, which is convenient when doing
mass attribute assignment.

```rb
user.avatar = file_hash
# or
attacher.assign(file_hash)
```

Internally the Rack uploaded file hash will be converted into an IO object
using `Shrine.rack_file`, which you can also use directly:

```rb
# or YourUploader.rack_file(file_hash)
io = Shrine.rack_file(file_hash)
io.original_filename #=> "cats.png"
io.content_type      #=> "image/png"
io.size              #=> 58342
```

Note that this plugin is not needed in Rails applications, as Rails already
wraps the Rack uploaded file hash into an `ActionDispatch::Http::UploadedFile`
object.
