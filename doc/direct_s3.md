# Direct Uploads to S3

Shrine gives you the ability to upload files directly to Amazon S3, which is
beneficial for several use cases:

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
  uploading a large files to S3 or any external service inside the
  request-response lifecycle might not be able to finish before the request
  times out.

You can start by setting both temporary and permanent storage to S3 with
different prefixes (or even buckets):

```rb
# Gemfile
gem "aws-sdk-s3", "~> 1"
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
CORS. You can do that in the AWS S3 Console by clicking on "Properties >
Permissions > Add CORS Configuration", and then just follow the Amazon
documentation on how to write a CORS file.

http://docs.aws.amazon.com/AmazonS3/latest/dev/cors.html

Note that it may take some time for the CORS settings to be applied, due to
DNS propagation.

## File hash

After direct S3 uploads we'll need to manually construct Shrine's
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

When the user selects the file, we dynamically fetch the presign from the
server, and use this information to start uploading the file to S3. The
`direct_upload` plugin gives us this presign route, so we just need to mount it
in our application:

```rb
# Gemfile
gem "roda"
```
```rb
plugin :direct_upload
```
```rb
Rails.application.routes.draw do
  mount ImageUploader::UploadEndpoint => "/images"
end
```

This gives your application a `GET /images/cache/presign` route, which
returns the S3 URL which the file should be uploaded to, along with the
necessary request parameters:

```rb
# GET /images/cache/presign
{
  "url" => "https://my-bucket.s3-eu-west-1.amazonaws.com",
  "fields" => {
    "key" => "cache/b7d575850ba61b44c8a9ff889dfdb14d88cdc25f8dd121004c8",
    "policy" => "eyJleHBpcmF0aW9uIjoiMjAxNS0QwMToxMToyOVoiLCJjb25kaXRpb25zIjpbeyJidWNrZXQiOiJzaHJpbmUtdGVzdGluZyJ9LHsia2V5IjoiYjdkNTc1ODUwYmE2MWI0NGU3Y2M4YTliZmY4OGU5ZGZkYjE2NTQ0ZDk4OGNkYzI1ZjhkZDEyMTAwNGM4In0seyJ4LWFtei1jcmVkZW50aWFsIjoiQUtJQUlKRjU1VE1aWlk0NVVUNlEvMjAxNTEwMjQvZXUtd2VzdC0xL3MzL2F3czRfcmVxdWVzdCJ9LHsieC1hbXotYWxnb3JpdGhtIjoiQVdTNC1ITUFDLVNIQTI1NiJ9LHsieC1hbXotZGF0ZSI6IjIwMTUxMDI0VDAwMTEyOVoifV19",
    "x-amz-credential" => "AKIAIJF55TMZYT6Q/20151024/eu-west-1/s3/aws4_request",
    "x-amz-algorithm" => "AWS4-HMAC-SHA256",
    "x-amz-date" => "20151024T001129Z",
    "x-amz-signature" => "c1eb634f83f96b69bd675f535b3ff15ae184b102fcba51e4db5f4959b4ae26f4"
  }
}
```

For uploading to S3 you'll probably want to use a JavaScript file upload
library like [jQuery-File-Upload], [Dropzone] or [FineUploader]. After the
upload you should create a JSON representation of the uploaded file, which you
can write to the hidden attachment field:

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

See the [demo app] for an example JavaScript implementation of multiple direct
S3 uploads.

## Strategy B (static)

* Basic user experience
* Only for single uploads
* No JavaScript needed

An alternative to the previous strategy is generating a file upload form
immediately when the page is rendered, and then file upload can be either
asynchronous, or synchronous with redirection. For generating the form we can
use `Shrine::Storage::S3#presign`, which returns a [`Aws::S3::PresignedPost`]
object, which has `#url` and `#fields` methods:

```erb
<% presign = Shrine.storages[:cache].presign(SecureRandom.hex, success_action_redirect: new_album_url) %>

<form action="<%= presign.url %>" method="post" enctype="multipart/form-data">
  <input type="file" name="file">
  <% presign.fields.each do |name, value| %>
    <input type="hidden" name="<%= name %>" value="<%= value %>">
  <% end %>
  <input type="submit" value="Upload">
</form>
```

If you're doing synchronous upload with redirection, the redirect URL will
include the object key in the query parameters, which you can use to generate
Shrine's uploaded file representation:

```erb
<%
  cached_file = {
    storage: "cache",
    id: params[:key][/cache\/(.+)/, 1], # we have to remove the prefix part
    metadata: {},
  }
%>

<form action="/albums" method="post">
  <input type="hidden" name="album[image]" value="<%= cached_file.to_json %>">
  <input type="submit" value="Save">
</form>
```

## Metadata

With direct uploads any metadata has to be extracted on the client, since
caching the file doesn't touch your application. When the cached file is stored,
Shrine's default behaviour is to simply copy over cached file's metadata.

If you want to re-extract metadata on the server before file validation, you
can load the `restore_cached_data`. That will make Shrine open the S3 file for
reading, give it for metadata extraction, and then override the metadata
received from the client with one extracted by Shrine.

```rb
plugin :restore_cached_data
```

Note that if you don't need this metadata before file validation, and you would
like to have it extracted in a background job, you can do the following trick:

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

Since directly uploaded files will stay in your temporary storage, you will
want to periodically delete the old ones that were already promoted. Luckily,
Amazon provides [a built-in solution](http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html)
for that.

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

[`Aws::S3::PresignedPost`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Bucket.html#presigned_post-instance_method
[demo app]: https://github.com/janko-m/shrine/tree/master/demo
[Dropzone]: https://github.com/enyo/dropzone
[jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
[FineUploader]: https://github.com/FineUploader/fine-uploader
[Amazon S3 Data Consistency Model]: http://docs.aws.amazon.com/AmazonS3/latest/dev/Introduction.html#ConsistencyMode
