# Testing with Shrine

The goal of this guide is to provide some useful tips for testing file
attachments implemented with Shrine in your application.

## Callbacks

When you first try to test file attachments, you might experience that files
are simply not being promoted (uploaded from temporary to permanent storage).
This is because your tests are likely setup to be wrapped inside database
transactions, and that doesn't work with Shrine callbacks.

Specifically, Shrine uses "after commit" callbacks for promoting and deleting
attached files. This means that if your tests are wrapped inside transactions,
those Shrine actions will happen only after those transactions commit, which
happens only after the test has already finished.

```rb
# Promoting will happen only after the test transaction commits
it "can attach images" do
  photo = Photo.create(image: image_file)
  photo.image.storage_key #=> :cache (we expected it to be promoted to permanent storage)
end
```

For file attachments to properly work, you'll need to disable transactions for
those tests. For Rails apps you can tell Rails not to use transactions, and
instead use libraries like [DatabaseCleaner] which allow you to use table
truncation or deletion strategies instead of transactions.

```rb
RSpec.configure do |config|
  config.use_transactional_fixtures = false
end
```

## Storage

If you're using an external storage in development, it is common in tests to
switch to a filesystem storage. However, that means that you'll also have to
clean up the test directory between tests, and writing to filesystem can affect
the performance of your tests.

If your tests are run in a single process, instead of filesystem you can use
[memory storage][shrine-memory], which is both faster and doesn't require you
to clean up anything between tests.

```rb
gem "shrine-memory"
```
```rb
# test/test_helper.rb
require "shrine/storage/memory"

Shrine.storages = {
  cache: Shrine::Storage::Memory.new,
  store: Shrine::Storage::Memory.new,
}
```

Alternatively, if you're using Amazon S3 storage, in tests you can use
[aws-sdk-ruby stubs].

## Test data

If you're creating test data dynamically using libraries like [factory_girl],
you can have the test file assigned dynamically when the record is created:

```rb
factory :photo do
  image { File.open("test/files/image.jpg") }
end
```

On the other hand, if you're setting up test data using Rails' YAML fixtures,
you unfortunately won't be able to use them for assigning files. This is
because Rails fixtures only allow assigning primitive data types, and don't
allow you to specify Shrine attributes - you can only assign to columns
directly.

## Background jobs

If you're using background jobs with Shrine, you probably want to make them
synchronous in tests. Your favourite backgrounding library should already
support this, examples:

```rb
# Sidekiq
require "sidekiq/testing"
Sidekiq::Testing.inline!
```

```rb
# SuckerPunch
require "sucker_punch/testing/inline"
```

```rb
# ActiveJob
ActiveJob::Base.queue_adapter = :inline
```

## Acceptance tests

In acceptance tests you're testing your app end-to-end, and you likely want to
also test file attachments here. There are a variety of libraries that you
might be using for your acceptance tests.

### Capybara

If you're testing with the [Capybara] acceptance test framework, you can use
[`#attach_file`] to select a file from your filesystem in the form:

```rb
attach_file("#image-field", "test/files/image.jpg")
```

### Rack::Test

Regular routing tests in Rails use [Rack::Test], in which case you can create
`Rack::Test::UploadedFile` objects and pass them as form parameters:

```rb
post "/photos", photo: {image: Rack::Test::UploadedFile.new("test/files/image.jpg", "image/jpeg")}
```

### Rack::TestApp

With [Rack::TestApp] you can create multipart file upload requests by using the
`:multipart` option and passing a `File` object:

```rb
http.post "/photos", multipart: {"photo[image]" => File.open("test/files/image.jpg")}
```

## Attachment

Even though all the file attachment logic is usually encapsulated in your
uploader classes, in general it's still best to test this logic through models.

In your controller the attachment attribute using the uploaded file from the
controller, in Rails case it's an `ActionDispatch::Http::UploadedFile`.
However, you can also assign plain `File` objects, or any other kind of IO-like
objects.

```rb
describe ImageUploader do
  it "generates image thumbnails" do
    photo = Photo.create(image: File.open("test/files/image.png"))
    assert_equal [:small, :medium, :large], photo.image.keys
  end
end
```

If you want test with an IO object that closely resembles the kind of IO that
is assigned by your web framework, you can use this:

```rb
require "forwardable"
require "stringio"

class FakeIO
  attr_reader :original_filename, :content_type

  def initialize(content, filename: nil, content_type: nil)
    @io = StringIO.new(content)
    @original_filename = filename
    @content_type = content_type
  end

  extend Forwardable
  delegate Shrine::IO_METHODS.keys => :@io
end
```

```rb
describe ImageUploader do
  it "generates image thumbnails" do
    photo = Photo.create(image: FakeIO.new(File.read("test/files/image.png")))
    assert_equal [:small, :medium, :large], photo.image.keys
  end
end
```

## Processing

In tests you usually don't want to perform processing, or at least don't want
it to be performed by default (only when you're actually testing it).

If you're processing only single files, you can override the `Shrine#process`
method in tests to return nil:

```rb
class ImageUploader
  def process(io, context)
    # don't do any processing
  end
end
```

If you're processing versions, you can override `Shrine#process` to simply
return a hash of unprocessed original files:

```rb
class ImageUploader
  def process(io, context)
    if context[:action] == :store
      {small: io.download, medium: io.download, large: io.download}
    end
  end
end
```

However, it's even better to design your processing code in such a way that
it's easier to swap out in tests. In your *application* code you could extract
processing into a single `#call`-able object, and register it inside uploader
generic `opts` hash.

```rb
class ImageUploader < Shrine
  opts[:processor] = ImageThumbnailsGenerator

  process(:store) do |io, context|
    opts[:processor].call(io, context)
  end
end
```

Now in your tests you can easily swap out `ImageThumbnailsGenerator` with
"fake" processing, which just returns the result in correct format (single file
or hash of versions). Since the only requirement of the processor is that it
responds to `#call`, we can just swap it out for a proc or a lambda:

```rb
ImageUploader.opts[:processor] = proc do |io, context|
  # return unprocessed file(s)
end
```

This also has the benefit of allowing you to test `ImageThumbnailsGenerator` in
isolation.

## Direct upload

If you've set up direct uploads to Amazon S3 (using the `presign_endpoint`
plugin), in tests you'll probably want to just use filesystem or memory storage
to avoid network requests.

The easiest way to do that is to add an `upload_endpoint`, modify it so that it
behaves like S3, and change `presign_endpoint` response to point to the upload
endpoint. Here is how one could modify the test helper in a Rails application:

```rb
# test/test_helper.rb

# create and mount a fake S3 upload endpoint
Shrine.plugin :upload_endpoint
fake_s3 = Shrine.upload_endpoint(:cache, upload_context: -> (request) {
  { location: request.params["key"].match(/^cache\//).post_match }
})
Rails.application.routes.prepend { mount fake_s3 => "/s3" }

# override presigns to return URLs to the fake S3 upload endpoint
Shrine.plugin :presign_endpoint, presign: -> (id, options, request) do
  Struct.new(:url, :fields).new("#{request.base_url}/s3", { "key" => "cache/#{id}" })
end
```

[DatabaseCleaner]: https://github.com/DatabaseCleaner/database_cleaner
[shrine-memory]: https://github.com/janko-m/shrine-memory
[factory_girl]: https://github.com/thoughtbot/factory_girl
[Capybara]: https://github.com/jnicklas/capybara
[`#attach_file`]: http://www.rubydoc.info/github/jnicklas/capybara/master/Capybara/Node/Actions#attach_file-instance_method
[Rack::Test]: https://github.com/brynary/rack-test
[Rack::TestApp]: https://github.com/kwatch/rack-test_app
[aws-sdk-ruby stubs]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/ClientStubs.html
