# Direct Uploads to S3

Probably the best way to do file uploads is to upload them directly to S3, and
afterwards do processing in a background job. Direct S3 uploads are a bit more
involved, so we'll explain the process.

## Enabling CORS

First thing that we need to do is enable CORS on our S3 bucket. You can do that
by clicking on "Properties > Permissions > Add CORS Configuration", and
then just follow the Amazon documentation on how to write a CORS file.

http://docs.aws.amazon.com/AmazonS3/latest/dev/cors.html

Note that it may take some time for the CORS settings to be applied, due to
DNS propagation.

## Static upload

If you're doing just a single file upload in your form, you can generate
upfront the fields necessary for direct S3 uploads using
`Shrine::Storage::S3#presign`. This method returns a [`Aws::S3::PresignedPost`]
object, which has `#url` and `#fields`, which you could use like this:

```erb
<% presign = Shrine.storages[:cache].presign(SecureRandom.hex) %>

<form action="<%= presign.url %>" method="post" enctype="multipart/form-data">
  <input type="file" name="file">
  <% presign.fields.each do |name, value| %>
    <input type="hidden" name="<%= name %>" value="<%= value %>">
  <% end %>
</form>
```

You can also pass additional options to `#presign`:

```rb
Shrine.storages[:cache].presign(SecureRandom.hex,
  content_length_range: 0..(5*1024*1024), # Limit of 5 MB
  success_action_redirect: webhook_url,   # Tell S3 where to redirect
  # ...
)
```

## Dynamic upload

If the frontend is separate from the backend, or you want to do multiple file
uploads, you need to generate these presigns dynamically. The `direct_upload`
plugins provides a route just for that:

```rb
plugin :direct_upload, presign: true
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

You can use this data in a similar way as with static upload. See
the [example app] for how multiple file upload to S3 can be done using
[jQuery-File-Upload].

If you want to pass additional options to `Storage::S3#presign`, you can pass
a block to `:presign`:

```rb
plugin :direct_upload, presign: ->(request) do # yields a Roda request object
  {success_action_redirect: "http://example.com/webhook"}
end
```

## File hash

Once you've uploaded the file to S3, you need to create the representation of
the uploaded file which Shrine will understand. This is how a Shrine's uploaded
file looks like:

```rb
{
  "id" => "349234854924394",
  "storage" => "cache",
  "metadata" => {
    "size" => 45461,
    "filename" => "foo.jpg",     # optional
    "mime_type" => "image/jpeg", # optional
  }
}
```

The `id`, `storage` and `metadata.size` fields are required, and the rest of
the metadata is optional. You need to assign a JSON representation of this
hash to the model in place of the attachment.

```rb
user.avatar = '{"id":"43244656","storage":"cache",...}'
```

In a form you can assign this to an appropriate "hidden" field.

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
happens soon after uploading to cache. If you start noticing these errors, and
you're using `background_helpers` plugin, you can tell your backgrounding
library to perform the job with a delay:

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
