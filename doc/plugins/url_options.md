---
title: URL Options
---

The [`url_options`][url_options] plugin allows you to specify
URL options that will be applied by default for uploaded files of specified
storages. `url_options` are parameters specific to the storage service.

```rb
plugin :url_options, store: { expires_in: 24*60*60 } # `expires_in` is a URL option for AWS S3
```

You can also generate the default URL options dynamically by using a block,
which will receive the UploadedFile object along with any options that were
passed to `UploadedFile#url`.

```rb
plugin :url_options, store: -> (file, options) do
  { response_content_disposition: ContentDisposition.attachment(file.original_filename) }
end
```

In both cases the default options are merged with options passed to
`UploadedFile#url`, and the latter will always have precedence over default
options.

[url_options]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/url_options.rb
