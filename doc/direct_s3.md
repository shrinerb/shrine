# Direct Uploads to S3

Shrine gives you the ability to upload files directly to Amazon S3 (or any
other storage service that accepts direct uploads). Uploading directly to a
storage service is beneficial for several reasons:

* Accepting uploads is resource-intensive for the server, and delegating it to
  an external service makes scaling easier.

* If both temporary and permanent storage are S3, promoting an S3 file to
  permanent storage will simply issue an S3 copy request, without any
  downloading and reuploading.

* With multiple servers it's generally not possible to cache files to the disk,
  unless you're using a distibuted filesystem that's shared between servers.

* On Heroku any uploaded files that aren't part of version control don't persist,
  they get removed each time you do a new deploy or when the dyno automatically
  changes the location.

* If your request workers have a timeout configured or you're using Heroku,
  uploading large files to S3 or any external service inside the
  request-response lifecycle might not be able to finish before the request
  times out.

To start, let's set both temporary and permanent storage to S3, with the
temporary storage uploading to the `cache/` directory:

```rb
# Gemfile
gem "shrine", "~> 2.11"
gem "aws-sdk-s3", "~> 1.2"
```
```rb
require "shrine/storage/s3"

s3_options = {
  access_key_id:     "<YOUR KEY>",
  secret_access_key: "<YOUR SECRET>",
  bucket:            "<YOUR BUCKET>",
  region:            "<REGION>",
}

Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(**s3_options),
}
```

## Enabling CORS

In order to be able upload files directly to your S3 bucket, you need enable
CORS. You can do that from the AWS S3 Console by going to your bucket, clicking
on the "Permissions" tab, then on "CORS Configuration", and following the
[guide for configuring CORS][CORS guide].

Alternatively you can configure CORS via an [API call][CORS API]:

```rb
require "aws-sdk-s3"

client = Aws::S3::Client.new(
  access_key_id:     "<YOUR KEY>",
  secret_access_key: "<YOUR SECRET>",
  region:            "<REGION>",
)

client.put_bucket_cors(
  bucket: "<YOUR BUCKET>",
  cors_configuration: {
    cors_rules: [{
      allowed_headers: ["Authorization", "Content-Type", "Origin"],
      allowed_methods: ["GET", "POST", "PUT"],
      allowed_origins: ["*"],
      max_age_seconds: 3000,
    }]
  }
)
```

Note that due to DNS propagation it may take some time for the CORS update to
be applied.

## Strategy A (dynamic)

* Best user experience
* Single or multiple file uploads
* Some JavaScript needed

When the user selects a file in the form, on the client-side we asynchronously
fetch the presign information from the server, and use this information to
upload the file to S3. The `presign_endpoint` plugin gives us this presign
route, so we just need to mount it in our application:

```rb
Shrine.plugin :presign_endpoint, presign_options: { method: :put }
```
```rb
# config.ru (Rack)
map "/presign" do
  run Shrine.presign_endpoint(:cache)
end

# OR

# config/routes.rb (Rails)
Rails.application.routes.draw do
  mount Shrine.presign_endpoint(:cache) => "/presign"
end
```

The above will create a `GET /presign` route, which internally calls
[`Shrine::Storage::S3#presign`], returning the HTTP verb (PUT) and the S3 URL
to which the file should be uploaded, along with the required parameters (will
only be present for POST presigns) and request headers.

```rb
# GET /presign
{
  "method": "put",
  "url": "https://my-bucket.s3.eu-central-1.amazonaws.com/cache/my-key?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIMDH2HTSB3RKB4WQ%2F20180424%2Feu-central-1%2Fs3%2Faws4_request&X-Amz-Date=20180424T212022Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=1036b9cefe52f0b46c1f257f6817fc3c55cd8d9004f87a38cf86177762359375",
  "fields": {},
  "headers": {}
}
```

On the client side you can make it so that, when the user selects a file,
upload parameters are fetched from presign endpoint, and are used to upload
the selected file directly to S3. It's recommended to use [Uppy] for this.

Once the file has been uploaded, you can generate a JSON representation of the
uploaded file on the client-side, and write it to the hidden attachment field
(or send it directly in an AJAX request).

```rb
{
  "id": "302858ldg9agjad7f3ls.jpg",
  "storage": "cache",
  "metadata": {
    "size": 943483,
    "filename": "nature.jpg",
    "mime_type": "image/jpeg",
  }
}
```

* `id` – location of the file on S3 (minus the `:prefix`)
* `storage` – direct uploads typically use the `:cache` storage
* `metadata` – hash of metadata extracted from the file

Once submitted this JSON will then be assigned to the attachment attribute
instead of the raw file. See [this walkthrough][direct S3 upload walkthrough]
for adding dynamic direct S3 uploads from scratch using [Uppy], as well as the
[Roda][roda demo] or [Rails][rails demo] demo app for a complete example of
multiple direct S3 uploads.

## Strategy B (static)

* Basic user experience
* Only for single uploads
* No JavaScript needed

An alternative to the previous strategy is to generate an S3 upload form on
page render. The user can then select a file and submit it directly to S3. For
generating the form can use [`Shrine::Storage::S3#presign`], which returns URL
and form fields that should be used for the upload.

```rb
presigned_data = Shrine.storages[:cache].presign(
  SecureRandom.hex,
  success_action_redirect: new_album_url
)

Forme.form(action: presigned_data[:url], method: "post", enctype: "multipart/form-data") do |f|
  presigned_data[:fields].each do |name, value|
    f.input :hidden, name: name, value: value
  end
  f.input :file, name: "file"
  f.input :submit, value: "Upload"
end
```

Note the additional `:success_action_redirect` option which tells S3 where to
redirect to after the file has been uploaded. If you're using the Rails form
builder to generate this form, you might need to also tell S3 to ignore the
additional `utf8` and `authenticity_token` fields that Rails generates:

```rb
presigned_data = Shrine.storages[:cache].presign(
  SecureRandom.hex,
  allow_any: ["utf8", "authenticity_token"],
  success_action_redirect: new_album_url
)

# ...
```

Let's assume we specified the redirect URL to be a page which renders the form
for a new record. S3 will include some information about the upload in form of
GET parameters in the URL, out of which we only need the `key` parameter:

```rb
cached_file = {
  storage: "cache",
  id: request.params[:key][/cache\/(.+)/, 1], # we subtract the storage prefix
  metadata: {},
}

Forme.form(@album, action: "/albums", method: "post") do |f|
  f.input :image, type: :hidden, value: cached_file.to_json
  f.button "Save"
end
```

## Object data

When the cached S3 object is copied to permanent storage, the destination S3
object will by default inherit any object data that was assigned to the cached
object via presign parameters. However, S3 will by default also ignore any new
object parameters that are given to the copy request.

Whether object data will be copied or replaced depends on the value of the
`:metadata_directive` parameter:

* `"COPY"` - destination object will inherit source object data and any new data will be ignored (default)
* `"REPLACE"` - destination object will not inherit any of the source object data and will accept new data

You can use the `upload_options` plugin to change the `:metadata_directive`
option when S3 objects are copied:

```rb
plugin :upload_options, store: -> (io, context) do
  { metadata_directive: "REPLACE" } if io.is_a?(Shrine::UploadedFile)
end
```

## Shrine metadata

With direct uploads any metadata has to be extracted on the client-side, since
the file upload doesn't touch the application, so the Shrine uploader doesn't
get a chance to extract the metadata. When directly uploaded file is promoted
to permanent storage, Shrine's default behaviour is to just copy the received
metadata.

If you want to re-extract metadata on the server before file validation, you
can load the `restore_cached_data`. That will make Shrine open the S3 file for
reading, pass it for metadata extraction, and then override the metadata
received from the client with the extracted ones.

```rb
plugin :restore_cached_data
```

Note that if you don't need this metadata before file validation, and you would
like to have it extracted in a background job, you can do that with the
following trick:

```rb
class MyUploader < Shrine
  plugin :processing
  plugin :refresh_metadata

  process(:store) do |io, context|
    io.refresh_metadata!
    io # return the same cached IO
  end
end
```

## Checksum

To have AWS S3 verify the integrity of the uploaded data, you can use a
checksum. For that you first need to tell AWS S3 that you're going to be
including the `Content-MD5` request header in the upload request, by adding
the `:content_md5` presign option.

```rb
Shrine.plugin :presign_endpoint, presign_options: -> (request) do
  {
    content_md5: request.params["checksum"],
    method: :put,
  }
end
```

With the above setup, you can pass the MD5 hash of the file via the `checksum`
query parameter in the request to the presign endpoint. See [this
walkthrough][checksum walkthrough] for a complete JavaScript solution.

## Clearing cache

Directly uploaded files won't automatically be deleted from your temporary
storage, so you'll want to periodically clear them. One way to do that is
by setting up recurring script which calls `Shrine::Storage::S3#clear!`:

```rb
s3 = Shrine.storages[:cache]
s3.clear! { |object| object.last_modified < Time.now - 7*24*60*60 } # delete files older than 1 week
```

Alternatively you can add a bucket lifeycle rule to do this for you. This can
be done either from the [AWS Console][lifecycle Console] or via an [API
call][lifecycle API]:

```rb
require "aws-sdk-s3"

client = Aws::S3::Client.new(
  access_key_id:     "<YOUR KEY>",
  secret_access_key: "<YOUR SECRET>",
  region:            "<REGION>",
)

client.put_bucket_lifecycle_configuration(
  bucket: "<YOUR BUCKET>",
  lifecycle_configuration: {
    rules: [{
      expiration: { days: 7 },
      filter: { prefix: "cache/" },
      id: "cache-clear",
      status: "Enabled"
    }]
  }
)
```

## Eventual consistency

When uploading objects to Amazon S3, sometimes they may not be available
immediately. This can be a problem when using direct S3 uploads, because
usually in this case you're using S3 for both cache and store, so the S3 object
is moved to store soon after caching.

> Amazon S3 provides eventual consistency for some operations, so it is
> possible that new data will not be available immediately after the upload,
> which could result in an incomplete data load or loading stale data. COPY
> operations where the cluster and the bucket are in different regions are
> eventually consistent. All regions provide read-after-write consistency for
> uploads of new objects with unique object keys. For more information about
> data consistency, see [Amazon S3 Data Consistency Model] in the *Amazon Simple
> Storage Service Developer Guide*.

This means that in certain cases copying from cache to store can fail if it
happens immediately after uploading to cache. If you start noticing these
errors, and you're using `backgrounding` plugin, you can tell your
backgrounding library to perform the job with a delay:

```rb
Shrine.plugin :backgrounding

Shrine::Attacher.promote do |data|
  PromoteJob.perform_in(3, data) # tells a Sidekiq worker to perform in 3 seconds
end
```

## Testing

To avoid network requests in your test and development environment, you can use
[Minio]. Minio is an open source object storage server with AWS S3 compatible
API which you can run locally. See how to set it up in the [Testing][minio
setup] guide.

[`Shrine::Storage::S3#presign`]: https://shrinerb.com/rdoc/classes/Shrine/Storage/S3.html#method-i-presign
[`Aws::S3::PresignedPost`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Bucket.html#presigned_post-instance_method
[direct S3 upload walkthrough]: https://gist.github.com/janko-m/9aea154d72eb85b1fbfa16e1d77946e5#adding-direct-s3-uploads-to-a-roda--sequel-app-with-shrine
[checksum walkthrough]: https://gist.github.com/janko-m/4470b5fb0737c5c1f8bcfe8cdc3fd296#using-checksums-to-verify-integrity-of-direct-uploads-with-shrine--uppy
[roda demo]: https://github.com/shrinerb/shrine/tree/master/demo
[rails demo]: https://github.com/erikdahlstrand/shrine-rails-example
[Uppy]: https://uppy.io
[Amazon S3 Data Consistency Model]: http://docs.aws.amazon.com/AmazonS3/latest/dev/Introduction.html#ConsistencyMode
[CORS guide]: http://docs.aws.amazon.com/AmazonS3/latest/dev/cors.html
[CORS API]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#put_bucket_cors-instance_method
[lifecycle Console]: http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html
[lifecycle API]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#put_bucket_lifecycle_configuration-instance_method
[Minio]: https://minio.io
[minio setup]: https://shrinerb.com/rdoc/files/doc/testing_md.html#label-Minio
