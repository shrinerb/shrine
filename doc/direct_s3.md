# Direct Uploads to S3

Probably the best way to do file uploads is to upload them directly to S3, and
then upon saving the record when file is moved to a permanent place, put that
and any additional file processing in the background. The goal of this guide
is to provide instructions, as well as evaluate possible ways of doing this.

```rb
require "shrine/storage/s3"

Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(prefix: "store", **s3_options),
}
```

## Enabling CORS

First thing that you need to do is enable CORS on your S3 bucket. You can do
that by clicking on "Properties > Permissions > Add CORS Configuration", and
then just follow the Amazon documentation on how to write a CORS file.

http://docs.aws.amazon.com/AmazonS3/latest/dev/cors.html

Note that it may take some time for the CORS settings to be applied, due to
DNS propagation.

## File hash

Shrine's JSON representation of an uploaded file looks like this:

```rb
{
  "id": "349234854924394", # requied
  "storage": "cache", # required
  "metadata": {
    "size": 45461, # required
    "filename": "foo.jpg", # optional
    "mime_type": "image/jpeg", # optional
  }
}
```

The `id`, `storage` and `metadata.size` fields are required, and the rest of
the metadata is optional. After uploading the file to S3, you need to construct
this JSON and assign it to the hidden attachment field in the form.

## Strategy A (dynamic)

* Best user experience
* Single or multiple file uploads
* Some JavaScript needed

You can configure the `direct_upload` plugin to expose the presign route, and
mount the endpoint:

```rb
plugin :direct_upload, presign: true
```
```rb
Rails.application.routes.draw do
  mount ImageUploader.direct_endpoint => "attachments/image"
end
```

This gives the endpoint a `GET /:storage/presign` route, which generates a
presign object and returns it as JSON:

```rb
{
  "url" => "https://my-bucket.s3-eu-west-1.amazonaws.com",
  "fields" => {
    "key" => "b7d575850ba61b44c8a9ff889dfdb14d88cdc25f8dd121004c8",
    "policy" => "eyJleHBpcmF0aW9uIjoiMjAxNS0QwMToxMToyOVoiLCJjb25kaXRpb25zIjpbeyJidWNrZXQiOiJzaHJpbmUtdGVzdGluZyJ9LHsia2V5IjoiYjdkNTc1ODUwYmE2MWI0NGU3Y2M4YTliZmY4OGU5ZGZkYjE2NTQ0ZDk4OGNkYzI1ZjhkZDEyMTAwNGM4In0seyJ4LWFtei1jcmVkZW50aWFsIjoiQUtJQUlKRjU1VE1aWlk0NVVUNlEvMjAxNTEwMjQvZXUtd2VzdC0xL3MzL2F3czRfcmVxdWVzdCJ9LHsieC1hbXotYWxnb3JpdGhtIjoiQVdTNC1ITUFDLVNIQTI1NiJ9LHsieC1hbXotZGF0ZSI6IjIwMTUxMDI0VDAwMTEyOVoifV19",
    "x-amz-credential" => "AKIAIJF55TMZYT6Q/20151024/eu-west-1/s3/aws4_request",
    "x-amz-algorithm" => "AWS4-HMAC-SHA256",
    "x-amz-date" => "20151024T001129Z",
    "x-amz-signature" => "c1eb634f83f96b69bd675f535b3ff15ae184b102fcba51e4db5f4959b4ae26f4"
  }
}
```

When the user attaches a file, you should first request the presign object from
the direct endpoint, and then upload the file to the given URL with the given
fields. For uploading to S3 you can use any of the great JavaScript libraries
out there, [jQuery-File-Upload] for example.

After the upload you create a JSON representation of the uploaded file and
usually write it to the hidden attachment field in the form:

```js
var image = {
  id: /cache\/(.+)/.exec(key)[1], # we have to remove the prefix part
  storage: 'cache',
  metadata: {
    size:      data.files[0].size,
    filename:  data.files[0].name,
    mime_type: data.files[0].type,
  }
}

$('input[type=file]').prev().value(JSON.stringify(image))
```

It's generally a good idea to disable the submit button until the file is
uploaded, as well as display a progress bar. See the [example app] for the
working implementation of multiple direct S3 uploads.

## Strategy B (static)

* Basic user experience
* Only for single uploads
* No JavaScript needed

An alternative to the previous strategy is generating a file upload form that
submits synchronously to S3, and then redirects back to your application.
For that you can use `Shrine::Storage::S3#presign`, which returns a
[`Aws::S3::PresignedPost`] object, which has `#url` and `#fields`:

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

After the file is submitted, S3 will redirect to the URL you specified and
include the object key as a query param:

```erb
<%
  id = params[:key][/cache\/(.+)/, 1] # we have to remove the prefix part
  cached_file = {
    storage: "cache",
    id: id,
    metadata: {
      size: Fastimage.size(Shrine.storages[:cache].url(id)), # requires the fastimage gem
    },
  }
%>

<form action="/albums" method="post">
  <input type="hidden" name="album[image]" value="<%= cached_file.to_json %>">
  <input type="submit" value="Save">
</form>
```

Notice that we needed to fetch the size of the uploaded file. The presence of
"size" metadata isn't required for this specific upload, but the absence of it
may cause problems later on when doing file migrations.

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
errors, and you're using `background_helpers` plugin, you can tell your
backgrounding library to perform the job with a delay:

```rb
Shrine.plugin :background_helpers
Shrine::Attacher.promote do |data|
  UploadJob.perform_in(60, data) # tells a Sidekiq worker to perform in 1 minute
end
```

[`Aws::S3::PresignedPost`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Bucket.html#presigned_post-instance_method
[example app]: https://github.com/janko-m/shrine-example
[jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
[Amazon S3 Data Consistency Model]: http://docs.aws.amazon.com/AmazonS3/latest/dev/Introduction.html#ConsistencyMode
