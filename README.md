# [Shrine]

Shrine is a toolkit for handling file attachments in Ruby applications. Some highlights:

* **Modular design** – the [plugin system] allows you to load only the functionality you need
* **Memory friendly** – streaming uploads and [downloads][Retrieving Uploads] make it work great with large files
* **Cloud storage** – store files on [disk][FileSystem], [AWS S3][S3], [Google Cloud][GCS], [Cloudinary] and others
* **Persistence integrations** – works with [Sequel], [ActiveRecord], [ROM], [Hanami] and [Mongoid] and others
* **Flexible processing** – generate thumbnails [up front] or [on-the-fly] using [ImageMagick] or [libvips]
* **Metadata validation** – [validate files][validation] based on [extracted metadata][metadata]
* **Direct uploads** – upload asynchronously [to your app][simple upload] or [to the cloud][presigned upload] using [Uppy]
* **Resumable uploads** – make large file uploads [resumable][resumable upload] on [S3][uppy-s3_multipart] or [tus][tus-ruby-server]
* **Background jobs** – built-in support for [background processing][backgrounding] that supports [any backgrounding library][Backgrounding Libraries]

Please follow along with the [Getting Started guide].

## Links

| Resource                | URL                                                                            |
| :----------------       | :----------------------------------------------------------------------------- |
| Website & Documentation | [shrinerb.com](https://shrinerb.com)                                           |
| Demo code               | [Roda][roda demo] / [Rails][rails demo]                                        |
| Wiki                    | [github.com/shrinerb/shrine/wiki](https://github.com/shrinerb/shrine/wiki)     |
| Help & Discussion       | [discourse.shrinerb.com](https://discourse.shrinerb.com)                       |

## Inspiration

Shrine was heavily inspired by [Refile] and [Roda]. From Refile it borrows the
idea of "backends" (here named "storages"), attachment interface, and direct
uploads. From Roda it borrows the implementation of an extensible plugin
system.

## Similar libraries

* Paperclip
* CarrierWave
* Dragonfly
* Refile
* Active Storage

## Code of Conduct

Everyone interacting in the Shrine project’s codebases, issue trackers, and
mailing lists is expected to follow the [Shrine code of conduct][CoC].

## License

The gem is available as open source under the terms of the [MIT License].

[Shrine]: https://shrinerb.com
[plugin system]: https://shrinerb.com/docs/getting-started#plugin-system
[Retrieving Uploads]: https://shrinerb.com/docs/retrieving-uploads
[FileSystem]: https://shrinerb.com/docs/storage/file-system
[S3]: https://shrinerb.com/docs/storage/s3
[GCS]: https://github.com/renchap/shrine-google_cloud_storage
[Cloudinary]: https://github.com/shrinerb/shrine-cloudinary
[Sequel]: https://shrinerb.com/docs/plugins/sequel
[ActiveRecord]: https://shrinerb.com/docs/plugins/activerecord
[ROM]: https://github.com/shrinerb/shrine-rom
[Hanami]: https://github.com/katafrakt/hanami-shrine
[Mongoid]: https://github.com/shrinerb/shrine-mongoid
[up front]: https://shrinerb.com/docs/getting-started#processing-up-front
[on-the-fly]: https://shrinerb.com/docs/getting-started#processing-on-the-fly
[ImageMagick]: https://github.com/janko/image_processing/blob/master/doc/minimagick.md#readme
[libvips]: https://github.com/janko/image_processing/blob/master/doc/vips.md#readme
[validation]: https://shrinerb.com/docs/validation
[metadata]: https://shrinerb.com/docs/metadata
[simple upload]: https://shrinerb.com/docs/getting-started#simple-direct-upload
[presigned upload]: https://shrinerb.com/docs/getting-started#presigned-direct-upload
[resumable upload]: https://shrinerb.com/docs/getting-started#resumable-direct-upload
[Uppy]: https://uppy.io/
[uppy-s3_multipart]: https://github.com/janko/uppy-s3_multipart
[tus-ruby-server]: https://github.com/janko/tus-ruby-server
[backgrounding]: https://shrinerb.com/docs/plugins/backgrounding
[Backgrounding Libraries]: https://github.com/shrinerb/shrine/wiki/Backgrounding-Libraries
[Getting Started guide]: https://shrinerb.com/docs/getting-started
[roda demo]: /demo
[rails demo]: https://github.com/erikdahlstrand/shrine-rails-example
[Refile]: https://github.com/refile/refile
[Roda]: https://github.com/jeremyevans/roda
[CoC]: /CODE_OF_CONDUCT.md
[MIT License]: /LICENSE.txt
