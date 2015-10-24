# Direct uploads to S3

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
<% presign = Shrine.storages[:cache].presign(SecureRandom.hex.to_s) %>

<form action="<%= presign.url %>" method="post" enctype="multipart/form-data">
  <input type="file" name="file">
  <% presign.fields.each do |name, value| %>
    <input type="hidden" name="<%= name %>" value="<%= value %>">
  <% end %>
</form>
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
  "url" => "https://shrine-testing.s3-eu-west-1.amazonaws.com",
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

[`Aws::S3::PresignedPost`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Bucket.html#presigned_post-instance_method
[example app]: https://github.com/janko-m/shrine-example
[jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
