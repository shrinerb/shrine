---
id: direct-s3
title: Direct Uploads to S3
---

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
temporary storage uploading to the `cache/` prefix:

```rb
# Gemfile
gem "shrine", "~> 2.11"
gem "aws-sdk-s3", "~> 1.14"
```
```rb
require "shrine/storage/s3"

s3_options = {
  bucket:            "<YOUR BUCKET>", # required
  access_key_id:     "<YOUR KEY>",
  secret_access_key: "<YOUR SECRET>",
  region:            "<REGION>",
}

Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(**s3_options),
}
```

## Bucket CORS configuration

In order to be able upload files directly to your S3 bucket, you'll need to
update your bucket's CORS configuration, as public uploads are not allowed by
default. You can do that from the AWS S3 Console by going to your bucket,
clicking on the "Permissions" tab and then on "CORS Configuration".

If you're using [Uppy], this is the recommended CORS configuration for the
[AWS S3 plugin][uppy aws-s3] that should work for both POST and PUT uploads:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <CORSRule>
    <AllowedOrigin>https://my-app.com</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
    <AllowedHeader>Authorization</AllowedHeader>
    <AllowedHeader>x-amz-date</AllowedHeader>
    <AllowedHeader>x-amz-content-sha256</AllowedHeader>
    <AllowedHeader>content-type</AllowedHeader>
    <AllowedHeader>content-disposition</AllowedHeader>
  </CORSRule>
  <CORSRule>
    <AllowedOrigin>*</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>
```

Replace `https://my-app.com` with the URL to your app (in development you can
set this to `*`). Once you've hit "Save", it may take some time for the
new CORS settings to be applied.

## Strategy A (dynamic)

* Best user experience
* Single or multiple file uploads
* Some JavaScript needed

When the user selects a file in the form, on the client side we asynchronously
fetch the upload parameters from the server, and use it to upload the file to
S3. It's recommended to use [Uppy] for client side uploads.

The `presign_endpoint` plugin provides a Rack application that generates these
upload parameters, which we can just mount in our application. We'll make our
presign endpoint also use the additional `type` and `filename` query parameters
to set `Content-Type` header, `Content-Disposition` header (using the
[content_disposition] gem), as well as limit the upload size to 10 MB (see
[`Shrine::Storage::S3#presign`] for the list of available options).

```rb
Shrine.plugin :presign_endpoint, presign_options: -> (request) {
  # Uppy will send the "filename" and "type" query parameters
  filename = request.params["filename"]
  type     = request.params["type"]

  {
    content_disposition:    ContentDisposition.inline(filename), # set download filename
    content_type:           type,                                # set content type (required if using DigitalOcean Spaces)
    content_length_range:   0..(10*1024*1024),                   # limit upload size to 10 MB
  }
}
```
```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  mount Shrine.presign_endpoint(:cache) => "/s3/params"
end
```

The above will create a `GET /s3/params` route, which internally calls
[`Shrine::Storage::S3#presign`] to return the HTTP verb (POST) and the S3 URL
to which the file should be uploaded, along with the required POST parameters
and request headers.

```rb
# GET /s3/params
{
  "method": "post",
  "url": "https://my-bucket.s3-eu-west-1.amazonaws.com",
  "fields": {
    "key": "b7d575850ba61b44c8a9ff889dfdb14d88cdc25f8dd121004c8",
    "policy": "eyJleHBpcmF0aW9uIjoiMjAxNS0QwMToxMToyOVoiLCJjb25kaXRpb25zIjpbeyJidWNrZXQiOiJ...",
    "x-amz-credential": "AKIAIJF55TMZYT6Q/20151024/eu-west-1/s3/aws4_request",
    "x-amz-algorithm": "AWS4-HMAC-SHA256",
    "x-amz-date": "20151024T001129Z",
    "x-amz-signature": "c1eb634f83f96b69bd675f535b3ff15ae184b102fcba51e4db5f4959b4ae26f4"
  },
  "headers": {}
}
```

Uppy's [AWS S3][uppy aws-s3] plugin would then make a request to this endpoint
and use these parameters to upload the file directly to S3. Once the file has
been uploaded, you can generate a JSON representation of the uploaded file on
the client side, and write it to the hidden attachment field (or send it
directly in an AJAX request).

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

Once the form is submitted, this JSON data will then be assigned to the
attachment attribute instead of the raw file. See [this walkthrough][direct S3
upload walkthrough] for adding dynamic direct S3 uploads from scratch, as well
as the [Roda][roda demo] / [Rails][rails demo] demo app for a complete example
of multiple direct S3 uploads.

Also, if you're dealing with larger files, you may want to make the uploads
resumable by using the [AWS S3 Multipart][uppy aws-s3-multipart] Uppy plugin
instead, with the [uppy-s3_multipart] gem on the backend. Your back-end
implementation is similar, just using `Shrine.uppy_s3_multipart` in place of
`Shrine.presign_endpoint`. Instructions can be found in the [gem
docs][uppy-s3_multipart shrine].

## Strategy B (static)

* Basic user experience
* Only for single uploads
* No JavaScript needed

An alternative to the previous strategy is to generate an S3 upload form on
page render. The user can then select a file and submit it directly to S3. For
generating the form can use [`Shrine::Storage::S3#presign`], which returns URL
and form fields that should be used for the upload.

```rb
presign_data = Shrine.storages[:cache].presign(
  SecureRandom.hex,
  success_action_redirect: new_album_url
)

form action: presign_data[:url], method: "post", enctype: "multipart/form-data" do |f|
  presign_data[:fields].each do |name, value|
    f.input :hidden, name: name, value: value
  end
  f.input :file, name: "file"
  f.button "Submit"
end
```

Note the additional `:success_action_redirect` option which tells S3 where to
redirect to after the file has been uploaded. If you're using the Rails form
builder to generate this form, you might need to also tell S3 to ignore the
additional `utf8` and `authenticity_token` fields that Rails generates:

```rb
presign_data = Shrine.storages[:cache].presign(
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
  id: params["key"][/^cache\/(.+)/, 1], # we subtract the storage prefix
  metadata: {},
}

form @album, action: "/albums" do |f|
  f.input :image, type: :hidden, value: cached_file.to_json
  f.button "Save"
end
```

## Shrine metadata

When attaching a file that was uploaded directly to S3, by default Shrine will
not extract metadata from the file, instead it will simply copy over any
metadata assigned on the client side. This is the default behaviour because
extracting metadata requires retrieving file content, which in this case means
additional HTTP requests.

See [this section][metadata direct uploads] or the rationale and instructions
on how to opt in.

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

Shrine::Attacher.promote_block do
  # tells a Sidekiq worker to perform in 3 seconds
  PromoteJob.perform_in(3, self.class.name, record.class.name, record.id, name, file_data)
end
```

## Checksums

You can have AWS S3 verify the integrity of the uploaded data by including a
checksum generated on the client side in the upload request. For that we'll
need to include the checksum in the presign request, which we can pass in via
the `checksum` query parameter. The `:content_md5` parameter is not supported
in POST presigns, so for this we'll need to switch to PUT.

```rb
Shrine.plugin :presign_endpoint, presign_options: -> (request) do
  {
    method: :put,
    content_md5: request.params["checksum"],
  }
end
```

See [this walkthrough][checksum walkthrough] for a complete JavaScript
implementation of checksums.

Note that PUT presigns don't support the `:content_length_range` option, but
they support `:content_length` instead. So, if you want to limit the upload
size during direct uploads, you can pass an additional `size` query parameter
to the presign request on the client side, and require it when generating
presign options:

```rb
Shrine.plugin :presign_endpoint, presign_options: -> (request) do
  {
    method: :put,
    content_length: request.params.fetch("size"),
    content_md5: request.params["checksum"],
  }
end
```

## Testing

To avoid network requests in your test and development environment, you can use
[Minio]. Minio is an open source object storage server with AWS S3 compatible
API which you can run locally. See how to set it up in the [Testing][minio
setup] guide.

[`Shrine::Storage::S3#presign`]: https://shrinerb.com/rdoc/classes/Shrine/Storage/S3.html#method-i-presign
[`Aws::S3::PresignedPost`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Bucket.html#presigned_post-instance_method
[direct S3 upload walkthrough]: https://github.com/shrinerb/shrine/wiki/Adding-Direct-S3-Uploads
[checksum walkthrough]: https://github.com/shrinerb/shrine/wiki/Using-Checksums-in-Direct-Uploads
[roda demo]: https://github.com/shrinerb/shrine/tree/master/demo
[rails demo]: https://github.com/erikdahlstrand/shrine-rails-example
[Uppy]: https://uppy.io
[uppy aws-s3]: https://uppy.io/docs/aws-s3/
[uppy aws-s3 cors]: https://uppy.io/docs/aws-s3/#S3-Bucket-configuration
[uppy aws-s3-multipart]: https://uppy.io/docs/aws-s3/
[uppy-s3_multipart]: https://github.com/janko/uppy-s3_multipart
[uppy-s3_multipart shrine]: https://github.com/janko/uppy-s3_multipart#shrine
[Amazon S3 Data Consistency Model]: http://docs.aws.amazon.com/AmazonS3/latest/dev/Introduction.html#ConsistencyMode
[CORS guide]: http://docs.aws.amazon.com/AmazonS3/latest/dev/cors.html
[CORS API]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#put_bucket_cors-instance_method
[lifecycle Console]: http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html
[lifecycle API]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#put_bucket_lifecycle_configuration-instance_method
[Minio]: https://minio.io
[minio setup]: https://shrinerb.com/docs/testing#minio
[metadata direct uploads]: https://shrinerb.com/docs/metadata#direct-uploads
[content_disposition]: https://github.com/shrinerb/content_disposition
