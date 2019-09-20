# Testing with Shrine

The goal of this guide is to provide some useful tips for testing file
attachments implemented with Shrine in your application.

## Callbacks

When you first try to test file attachments, you might experience that files
are not being promoted to permanent storage. This is because your tests are
likely setup to be wrapped inside database transactions, and that doesn't work
with Shrine callbacks.

Specifically, Shrine uses "after commit" callbacks for promoting and deleting
attached files. This means that if your tests are wrapped inside transactions,
those Shrine actions will happen only after those transactions commit, which
happens only after the test has already finished.

```rb
# Promoting will happen only after the test transaction commits
it "can attach images" do
  photo = Photo.create(image: file)
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

If you're using FileSystem storage and your tests run in a single process,
you can switch to `Shrine::Storage::Memory`, which is both faster and doesn't
require you to clean up anything between tests.

```rb
require "shrine/storage/memory"

Shrine.storages = {
  cache: Shrine::Storage::Memory.new,
  store: Shrine::Storage::Memory.new,
}
```

If you're using AWS S3 storage, you can use [MinIO] (explained below) instead
of S3, both in test and development environment. Alternatively, you can [stub
aws-sdk-s3 requests][aws-sdk-ruby stubs] in tests.

### MinIO

[MinIO] is an open source object storage server with AWS S3 compatible API which
you can run locally. The advantage of using MinIO for your development and test
environments is that all AWS S3 functionality should still continue to work,
including direct uploads, so you don't need to update your code.

If you're on a Mac you can install it with Homebrew:

```
$ brew install minio/stable/minio
```

Afterwards you can start the MinIO server and give it a directory where it will
store the data:

```
$ minio server data/
```

This command will print out the credentials for the running MinIO server, as
well as a link to the MinIO web interface. Follow that link and create a new
bucket. Once you've done that, you can configure `Shrine::Storage::S3` to use
your MinIO server:

```rb
Shrine::Storage::S3.new(
  access_key_id:     "<MINIO_ACCESS_KEY>", # "AccessKey" value
  secret_access_key: "<MINIO_SECRET_KEY>", # "SecretKey" value
  endpoint:          "<MINIO_ENDPOINT>",   # "Endpoint"  value
  bucket:            "<MINIO_BUCKET>",     # name of the bucket you created
  region:            "us-east-1",
  force_path_style:  true,
)
```

The `:endpoint` option will make aws-sdk-s3 point all URLs to your MinIO server
(instead of `s3.amazonaws.com`), and `:force_path_style` tells it not to use
subdomains when generating URLs.

## Test data

We want to keep our tests fast, so when we're setting up files for tests, we
want to avoid expensive operations such as file processing and metadata
extraction.

We can start by creating a method which would generate fake attachment data:

```rb
module TestData
  module_function

  def image_data
    attacher = Shrine::Attacher.new
    attacher.set(uploaded_image)

    # if you're processing derivatives
    attacher.set_derivatives(
      large:  uploaded_image,
      medium: uploaded_image,
      small:  uploaded_image,
    )

    attacher.column_data
  end

  def uploaded_image
    file = File.open("test/files/image.jpg", binmode: true)

    # for performance we skip metadata extraction and assign test metadata
    uploaded_file = Shrine.upload(file, :store, metadata: false)
    uploaded_file.metadata.merge!(
      "size"      => file.size,
      "mime_type" => "image/jpeg",
      "filename"  => "test.jpg",
    )

    uploaded_file
  end
end
```
```rb
TestData.image_data #=> '{"id":"...","storage":"...","metadata":{...},"derivatives":{...}}'
```

With [factory_bot] you can then assign the test attachment data like this:

```rb
factory :photo do
  image_data { TestData.image_data }
end
```

With [Rails' YAML fixtures][fixtures] it would look like this:

```erb
photo:
  image_data: <%= TestData.image_data %>
```

## Unit tests

For testing attachment in your unit tests, you can assign plain `File` objects:

```rb
RSpec.describe ImageUploader do
  let(:image)       { photo.image }
  let(:derivatives) { photo.image_derivatives }
  let(:photo)       { Photo.create(image: File.open("test/files/image.png", "rb")) }

  it "extracts metadata" do
    expect(image.mime_type).to eq("image/png")
    expect(image.extension).to eq("png")
    expect(image.size).to be_instance_of(Integer)
    expect(image.width).to be_instance_of(Integer)
    expect(image.height).to be_instance_of(Integer)
  end

  it "generates derivatives" do
    expect(derivatives[:small]).to  be_kind_of(Shrine::UploadedFile)
    expect(derivatives[:medium]).to be_kind_of(Shrine::UploadedFile)
    expect(derivatives[:large]).to  be_kind_of(Shrine::UploadedFile)
  end
end
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
post "/photos", photo: { image: Rack::Test::UploadedFile.new("test/files/image.jpg", "image/jpeg") }
```

### Rack::TestApp

With [Rack::TestApp] you can create multipart file upload requests by using the
`:multipart` option and passing a `File` object:

```rb
http.post "/photos", multipart: {"photo[image]" => File.open("test/files/image.jpg")}
```

## Background jobs

If you're using background jobs with Shrine, you probably want to make them
synchronous in tests. See your backgrounding library docs for how to make jobs
synchronous.

```rb
# ActiveJob
ActiveJob::Base.queue_adapter = :inline
```
```rb
# Sidekiq
require "sidekiq/testing"
Sidekiq::Testing.inline!
```
```rb
# SuckerPunch
require "sucker_punch/testing/inline"
```

## Processing

If you're testing your attachment flow which includes processing [derivatives],
you might want to disable the processing for certain tests. You can do this by
temporarily overriding the processor:

```rb
module TestMode
  module_function

  def disable_processing(attacher, processor_name = :default)
    attacher.class.instance_exec do
      original_processor = derivatives_processor
      derivatives_processor(processor_name) { Hash.new }
      yield
      derivatives_processor(processor_name, &original_processor)
    end
  end
end
```
```rb
TestMode.disable_processing(Photo.image_attacher) do
  photo = Photo.new
  photo.file = File.open("test/files/image.png", "rb")
  photo.save
end
```

[DatabaseCleaner]: https://github.com/DatabaseCleaner/database_cleaner
[factory_bot]: https://github.com/thoughtbot/factory_bot
[fixtures]: https://guides.rubyonrails.org/testing.html#the-low-down-on-fixtures
[Capybara]: https://github.com/jnicklas/capybara
[`#attach_file`]: http://www.rubydoc.info/github/jnicklas/capybara/master/Capybara/Node/Actions#attach_file-instance_method
[Rack::Test]: https://github.com/brynary/rack-test
[Rack::TestApp]: https://github.com/kwatch/rack-test_app
[aws-sdk-ruby stubs]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/ClientStubs.html
[MinIO]: https://min.io/
[derivatives]: /doc/plugins/derivatives.md#readme
