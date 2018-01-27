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

You can start by setting both temporary and permanent storage to S3 with
different prefixes (or even buckets):

```rb
# Gemfile
gem "aws-sdk-s3", "~> 1.2"
```
```rb
require "shrine/storage/s3"

s3_options = {
  access_key_id:     "abc",
  secret_access_key: "123",
  region:            "my-region",
  bucket:            "my-bucket",
}

Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(prefix: "store", **s3_options),
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
      allowed_methods: ["GET", "POST"],
      allowed_origins: ["*"],
      max_age_seconds: 3000,
    }]
  }
)
```

Note that due to DNS propagation it may take some time for update of the CORS
settings to be applied.

## File hash

After direct S3 uploads we'll need to manually construct Shrine's JSON
representation of an uploaded file:

```rb
{
  "id": "349234854924394", # requied
  "storage": "cache", # required
  "metadata": {
    "size": 45461, # optional, but recommended
    "filename": "foo.jpg", # optional
    "mime_type": "image/jpeg" # optional
  }
}
```

* `id` – location of the file on S3 (minus the `:prefix`)
* `storage` – direct uploads typically use the `:cache` storage
* `metadata` – hash of metadata extracted from the file

## Strategy A (dynamic)

* Best user experience
* Single or multiple file uploads
* Some JavaScript needed

When the user selects a file in the form, on the client-side we asynchronously
fetch the presign information from the server, and use this information to
upload the file to S3. The `presign_endpoint` plugin gives us this presign
route, so we just need to mount it in our application:

```rb
Shrine.plugin :presign_endpoint
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

The above will create a `GET /presign` route, which returns the S3 URL which
the file should be uploaded to, along with the required POST parameters and
request headers.

```rb
# GET /presign
{
  "url": "https://my-bucket.s3-eu-west-1.amazonaws.com",
  "fields": {
    "key": "cache/b7d575850ba61b44c8a9ff889dfdb14d88cdc25f8dd121004c8",
    "policy": "eyJleHBpcmF0aW9uIjoiMjAxNS0QwMToxMToyOVoiLCJjb25kaXRpb25zIjpbeyJidWNrZXQiOiJzaHJpbmUtdGVzdGluZyJ9LHsia2V5IjoiYjdkNTc1ODUwYmE2MWI0NGU3Y2M4YTliZmY4OGU5ZGZkYjE2NTQ0ZDk4OGNkYzI1ZjhkZDEyMTAwNGM4In0seyJ4LWFtei1jcmVkZW50aWFsIjoiQUtJQUlKRjU1VE1aWlk0NVVUNlEvMjAxNTEwMjQvZXUtd2VzdC0xL3MzL2F3czRfcmVxdWVzdCJ9LHsieC1hbXotYWxnb3JpdGhtIjoiQVdTNC1ITUFDLVNIQTI1NiJ9LHsieC1hbXotZGF0ZSI6IjIwMTUxMDI0VDAwMTEyOVoifV19",
    "x-amz-credential": "AKIAIJF55TMZYT6Q/20151024/eu-west-1/s3/aws4_request",
    "x-amz-algorithm": "AWS4-HMAC-SHA256",
    "x-amz-date": "20151024T001129Z",
    "x-amz-signature": "c1eb634f83f96b69bd675f535b3ff15ae184b102fcba51e4db5f4959b4ae26f4"
  },
  "headers": {}
}
```

On the client side you can then make a request to the presign endpoint as soon
as the user selects a file, and use the returned request information to upload
the selected file directly to S3. It's recommended to use [Uppy] for this.

Once the file has been uploaded, you can generate a JSON representation of the
uploaded file on the client-side, and write it to the hidden attachment field.
The `id` field needs to be equal to the `key` presign field minus the storage
`:prefix`.

```html
<input type='hidden' name='photo[image]' value='{
  "id": "302858ldg9agjad7f3ls.jpg",
  "storage": "cache",
  "metadata": {
    "size": 943483,
    "filename": "nature.jpg",
    "mime_type": "image/jpeg",
  }
}'>
```

This JSON string will now be submitted and assigned to the attachment attribute
instead of the raw file. See the [demo app] for an example JavaScript
implementation of multiple direct S3 uploads.

## Strategy B (static)

* Basic user experience
* Only for single uploads
* No JavaScript needed

An alternative to the previous strategy is to generate an S3 upload form on
page render. The user can then select a file and submit it directly to S3. For
generating the form we can use `Shrine::Storage::S3#presign`, which returns a
[`Aws::S3::PresignedPost`] object with `#url` and `#fields` attributes:

```erb
<%
  presign = Shrine.storages[:cache].presign SecureRandom.hex,
                                            success_action_redirect: new_album_url
%>

<form action="<%= presign.url %>" method="post" enctype="multipart/form-data">
  <% presign.fields.each do |name, value| %>
    <input type="hidden" name="<%= name %>" value="<%= value %>">
  <% end %>
  <input type="file" name="file">
  <input type="submit" value="Upload">
</form>
```

Note the additional `:success_action_redirect` option which tells S3 where to
redirect to after the file has been uploaded. If you're using the Rails form
builder to generate this form, you might need to also tell S3 to ignore the
additional `utf8` and `authenticity_token` fields that Rails generates:

```rb
<%
  presign = Shrine.storages[:cache].presign SecureRandom.hex,
                                            allow_any: ["utf8", "authenticity_token"],
                                            success_action_redirect: new_album_url
%>
```

Let's assume we specified the redirect URL to be a page which renders the form
for a new record. S3 will include some information about the upload in form of
GET parameters in the URL, out of which we only need the `key` parameter:

```erb
<%
  cached_file = {
    storage: "cache",
    id: params[:key][/cache\/(.+)/, 1], # we subtract the storage prefix
    metadata: {},
  }
%>

<form action="/albums" method="post">
  <input type="hidden" name="album[image]" value="<%= cached_file.to_json %>">
  <input type="submit" value="Save">
</form>
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

  process(:store) do |io, context|
    real_metadata = io.open { |opened_io| extract_metadata(opened_io, context) }
    io.metadata.update(real_metadata)
    io # return the same cached IO
  end
end
```

## Clearing cache

Directly uploaded files won't automatically be deleted from your temporary
storage, so you'll want to periodically clear them. One way to do that is
by setting up recurring script which calls `Shrine::Storage::S3#clear!`:

```rb
s3 = Shrine.storages[:cache]
s3.clear! { |object| object.last_modified < Time.now - 7*24*60*60 } # delete files older than 1 week
```

Alternatively you can add a bucket lifeycle rule to do this for you. This can
be done either from the [AWS Console][lifecycle console] or via an [API
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

[`Aws::S3::PresignedPost`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Bucket.html#presigned_post-instance_method
[demo app]: https://github.com/janko-m/shrine/tree/master/demo
[Uppy]: https://uppy.io
[Amazon S3 Data Consistency Model]: http://docs.aws.amazon.com/AmazonS3/latest/dev/Introduction.html#ConsistencyMode
[CORS guide]: http://docs.aws.amazon.com/AmazonS3/latest/dev/cors.html
[CORS API]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#put_bucket_cors-instance_method
[lifecycle Console]: http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html
[lifecycle API]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#put_bucket_lifecycle_configuration-instance_method
