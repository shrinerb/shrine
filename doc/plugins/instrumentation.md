---
title: Instrumentation
---

The [`instrumentation`][instrumentation] plugin publishes events for various
operations to a centralized notification component. In addition to that, it
provides default logging for these events.

```rb
Shrine.plugin :instrumentation
```

By default, the notification component is assumed to be
[ActiveSupport::Notifications], but [dry-monitor] is supported as well:

```rb
# Gemfile
gem "dry-monitor"
```
```rb
require "dry-monitor"

Shrine.plugin :instrumentation, notifications: Dry::Monitor::Notifications.new(:test)
```

## Logging

By default, the `instrumentation` plugin adds logging to the instrumented
events:

```rb
uploaded_file = Shrine.upload(StringIO.new("file"), :store)
uploaded_file.exists?
uploaded_file.download
uploaded_file.delete
```
```
Metadata (32ms) – {:storage=>:store, :io=>StringIO, :uploader=>Shrine}
Upload (1523ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :io=>StringIO, :upload_options=>{}, :uploader=>Shrine}
Exists (755ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :uploader=>Shrine}
Download (1002ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :download_options=>{}, :uploader=>Shrine}
Delete (700ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :uploader=>Shrine}
```

It uses `Shrine.logger` for logging, which allows you to change where and how
are the logs going to be written:

```rb
Shrine.logger = Rails.logger # in Rails apps
```

You can choose to log only certain events, e.g. we can exclude metadata
extraction:

```rb
Shrine.plugin :instrumentation, log_events: [
  :upload,
  :exists,
  :download,
  :delete,
]
```

You can also use your own log subscriber:

```rb
Shrine.plugin :instrumentation, log_subscriber: -> (event) {
  Shrine.logger.info JSON.generate(name: event.name, duration: event.duration, **event.payload)
}
```
```
{"name":"metadata","duration":0,"storage":"store","io":"#<StringIO:0x00007fd1d4a1b9d8>","options":{},"uploader":"Shrine"}
{"name":"upload","duration":0,"storage":"store","location":"dbeb3c3ed664059eb41a608e54a29f54","io":"#<StringIO:0x00007fd1d4a1b9d8>","upload_options":{},"options":{"location":"dbeb3c3ed664059eb41a608e54a29f54","metadata":{"filename":null,"size":4,"mime_type":null}},"uploader":"Shrine"}
{"name":"exists","duration":0,"storage":"store","location":"dbeb3c3ed664059eb41a608e54a29f54","uploader":"Shrine"}
{"name":"download","duration":0,"storage":"store","location":"dbeb3c3ed664059eb41a608e54a29f54","download_options":{},"uploader":"Shrine"}
{"name":"delete","duration":0,"storage":"store","location":"dbeb3c3ed664059eb41a608e54a29f54","uploader":"Shrine"}
```

Or disable logging altogether:

```rb
Shrine.plugin :instrumentation, log_subscriber: nil
```

## Events

The following events are instrumented by the `instrumentation` plugin:

* [`upload.shrine`](#uploadshrine)
* [`download.shrine`](#downloadshrine)
* [`open.shrine`](#openshrine)
* [`exists.shrine`](#existsshrine)
* [`delete.shrine`](#deleteshrine)
* [`metadata.shrine`](#metadatashrine)

### upload.shrine

The `upload.shrine` event is logged on `Shrine#upload`, and contains the
following payload:

| Key               | Description                            |
| :--               | :----                                  |
| `:storage`        | The storage identifier                 |
| `:location`       | The location of the uploaded file      |
| `:io`             | The uploaded IO object                 |
| `:upload_options` | Any upload options that were specified |
| `:metadata`       | Metadata extracted during upload       |
| `:options`        | Any additional uploader options        |
| `:uploader`       | The uploader class that sent the event |

### download.shrine

The `download.shrine` event is logged on `UploadedFile#stream` (which includes
`UploadedFile#download`), and contains the following payload:

| Key                 | Description                              |
| :--                 | :----                                    |
| `:storage`          | The storage identifier                   |
| `:location`         | The location of the uploaded file        |
| `:download_options` | Any download options that were specified |
| `:uploader`         | The uploader class that sent the event   |

### open.shrine

The `download.shrine` event is logged on `UploadedFile#open` or when uploaded
file is implicitly opened on calling an IO method.

| Key                 | Description                              |
| :--                 | :----                                    |
| `:storage`          | The storage identifier                   |
| `:location`         | The location of the uploaded file        |
| `:download_options` | Any download options that were specified |
| `:uploader`         | The uploader class that sent the event   |

### exists.shrine

The `exists.shrine` event is logged on `UploadedFile#exists?`, and contains the
following payload:

| Key               | Description                            |
| :--               | :----                                  |
| `:storage`        | The storage identifier                 |
| `:location`       | The location of the uploaded file      |
| `:uploader`       | The uploader class that sent the event |

### delete.shrine

The `delete.shrine` event is logged on `UploadedFile#delete`, and contains the
following payload:

| Key               | Description                            |
| :--               | :----                                  |
| `:storage`        | The storage identifier                 |
| `:location`       | The location of the uploaded file      |
| `:uploader`       | The uploader class that sent the event |

### metadata.shrine

The `metadata.shrine` event is logged on `Shrine#upload`, and contains the
following payload:

| Key               | Description                            |
| :--               | :----                                  |
| `:storage`        | The storage identifier                 |
| `:io`             | The uploaded IO object                 |
| `:options`        | Any options sent to the uploader       |
| `:uploader`       | The uploader class that sent the event |

## API

The `instrumentation` plugin adds `Shrine.instrument` and `Shrine.subscribe`
methods:

```rb
# sends a `my_event.shrine` event to the notifications component
Shrine.instrument(:my_event, { foo: "bar" }) do
  # do work
end
```
```rb
# subscribes to `my_event.shrine` events on the notifications component
Shrine.subscribe(:my_event) do |event|
  event.name #=> :my_event
  event.payload #=> { foo: "bar", uploader: Shrine }
  event[:foo] #=> "bar"
  event.duration #=> 15 (in milliseconds)
end
```

[instrumentation]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/instrumentation.rb
[ActiveSupport::Notifications]: https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html
[dry-monitor]: https://github.com/dry-rb/dry-monitor
