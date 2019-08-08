# Column

The [`column`][column] plugin provides interface for serializing and
deserializing attachment data in format suitable for persisting in a database
column (JSON by default).

```rb
plugin :column
```

## Serializing

The `Attacher#column_value` method returns attached file data in serialized
format, ready to be persisted into a database column.

```rb
attacher.attach(io)
attacher.column_value #=> '{"id":"...","storage":"...","metadata":{...}}'
```

If there is no attached file, `nil` is returned.

```rb
attacher.column_value #=> nil
```

If you want to retrieve this data as a *Hash*, use `Attacher#data` instead.

## Deserializing

The `Attacher.from_column` method instantiates the attacher from serialized
attached file data.

```rb
attacher = Shrine::Attacher.from_column('{"id":"...","storage":"...","metadata":{...}}')
attacher.file #=> #<Shrine::UploadedFile>
```

If `nil` is given, it means no attached file.

```rb
attacher = Shrine::Attacher.from_column(nil)
attacher.file #=> nil
```

Any additional options are forwarded to `Attacher#initialize`.

```rb
attacher = Shrine::Attacher.from_column('{...}', cache: :other_cache, store: :other_store)
attacher.file #=> nil
```

If you want to load attachment data into an existing attacher, use
`Attacher#load_column`.

```rb
attacher.file #=> nil
attacher.load_column('{"id":"...","storage":"...","metadata":{...}}')
attacher.file #=> #<Shrine::UploadedFile>
```

If you want to load attachment from a *Hash*, use `Attacher.from_data` or
`Attacher#load_data` instead.

## Serializer

By default the `JSON` standard library is used as the serializer, but you can
use your own serializer. The serializer object needs to implement `#dump` and
`#load` methods.

```rb
require "oj"

plugin :column, serializer: Oj # use custom serializer
```

If you want to disable serialization, you can set serializer to `nil`.

```rb
plugin :column, serializer: nil # disable serialization
```

You can also change the serializer on the attacher level:

```rb
Shrine::Attacher.new(column_serializer: Oj)  # use custom serializer
Shrine::Attacher.new(column_serializer: nil) # disable serialization
```

[column]: /lib/shrine/plugins/column.rb
