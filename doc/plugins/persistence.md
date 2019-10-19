---
title: Persistence
---

This is an internal plugin that provides uniform persistence interface across
different persistence plugins (e.g. [`activerecord`][activerecord],
[`sequel`][sequel]).

## Atomic promotion

If you're promoting cached file to permanent storage
[asynchronously][backgrounding], and want to handle the possibility of
attachment changing during promotion, you can use `Attacher#atomic_promote`:

```rb
# in your controller
attacher.attach_cached(io)
attacher.cached? #=> true
```
```rb
# in a background job
attacher.atomic_promote # promotes cached file and persists
attacher.stored? #=> true
```

After the cached file is uploaded to permanent storage, the record is reloaded
in order to check whether the attachment hasn't changed, and if it hasn't the
attachment is persisted. If the attachment has changed,
`Shrine::AttachmentChanged` exception is raised.

If you want to execute code after the attachment change check but before
persistence, you can pass a block:

```rb
attacher.atomic_promote do |reloaded_attacher|
  # run code after attachment change check but before persistence
end
```

You can pass `:reload` and `:persist` options to change how the record is
reloaded and pesisted. See the [`atomic_helpers`][atomic_helpers] plugin docs
for more details.

Any other options are forwarded to `Attacher#promote`:

```rb
attacher.atomic_promote(metadata: true) # re-extract metadata
```

## Atomic persistence

If you're updating something based on the attached file
[asynchronously][backgrounding], you might want to handle the possibility of
the attachment changing in the meanwhile. You can do that with
`Attacher#atomic_persist`:

```rb
# in a background job
attacher.refresh_metadata! # refresh_metadata plugin
attacher.atomic_persist # persists attachment data
```

The record is first reloaded in order to check whether the attachment hasn't
changed, and if it hasn't the attachment is persisted. If the attachment has
changed, `Shrine::AttachmentChanged` exception is raised.

If you want to execute code after the attachment change check but before
persistence, you can pass a block:

```rb
attacher.atomic_persist do |reloaded_attacher|
  # run code after attachment change check but before persistence
end
```

You can pass `:reload` and `:persist` options to change how the record is
reloaded and pesisted. See the [`atomic_helpers`][atomic_helpers] plugin docs
for more details.

## Simple Persistence

To simply save attachment changes to the underlying record, use
`Attacher#persist`:

```rb
attacher.attach(io)
attacher.persist # saves the underlying record
```

[activerecord]: https://shrinerb.com/docs/plugins/activerecord
[sequel]: https://shrinerb.com/docs/plugins/sequel
[backgrounding]: https://shrinerb.com/docs/plugins/backgrounding
