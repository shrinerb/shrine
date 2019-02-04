# hooks

The `hooks` plugin allows you to trigger some code around
processing/storing/deleting of each file.

```rb
plugin :hooks
```

Shrine uses instance methods for hooks. To define a hook for an uploader, you
just add an instance method to the uploader:

```rb
class ImageUploader < Shrine
  def around_process(io, context)
    super
  rescue
    ExceptionNotifier.processing_failed(io, context)
  end
end
```

Each hook will be called with 2 arguments, `io` and `context`. You should
always call `super` when overriding a hook, as other plugins may be using hooks
internally, and without `super` those wouldn't get executed.

Shrine calls hooks in the following order when uploading a file:

* `before_upload`
* `around_upload`
  - `before_process`
  - `around_process`
  - `after_process`
  - `before_store`
  - `around_store`
  - `after_store`
* `after_upload`

Shrine calls hooks in the following order when deleting a file:

* `before_delete`
* `around_delete`
* `after_delete`

By default every `around_*` hook returns the result of the corresponding
operation:

```rb
class ImageUploader < Shrine
  def around_store(io, context)
    result = super
    result.class #=> Shrine::UploadedFile
    result # it's good to always return the result for consistent behaviour
  end
end
```
