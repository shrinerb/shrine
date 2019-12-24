---
title: Column
---

The [`column`][column] plugin provides interface for serializing and
deserializing attachment data in format suitable for persisting in a database
column (JSON by default).

```rb
plugin :column
```

## Serializing

The `Attacher#column_data` method returns attached file data in serialized
format, ready to be persisted into a database column.

```rb
attacher.attach(io)
attacher.column_data #=> '{"id":"...","storage":"...","metadata":{...}}'
```

If there is no attached file, `nil` is returned.

```rb
attacher.column_data #=> nil
```

If you want to retrieve this data as a Hash, use `Attacher#data` instead.

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
attacher = Shrine::Attacher.from_column('{...}', store: :other_store)
attacher.store_key #=> :other_store
```

If you want to load attachment data into an existing attacher, use
`Attacher#load_column`.

```rb
attacher.file #=> nil
attacher.load_column('{"id":"...","storage":"...","metadata":{...}}')
attacher.file #=> #<Shrine::UploadedFile>
```

If you want to load attachment from a Hash, use `Attacher.from_data` or
`Attacher#load_data` instead.

## Serializer

By default, the `JSON` standard library is used for serializing hash data. With
the [`model`][model] and [`entity`][entity] plugin, the data is serialized
before writing to and deserialized after reading from the data attribute.

You can also use your own serializer via the `:serializer` option. The
serializer object needs to implement `#dump` and `#load` methods:

```rb
class MyDataSerializer
  def self.dump(data)
    data #=> { "id" => "...", "storage" => "...", "metadata" => { ... } }

    JSON.generate(data) # serialize data, e.g. into JSON
  end

  def self.load(data)
    data #=> '{"id":"...", "storage":"...", "metadata": {...}}'

    JSON.parse(data) # deserialize data, e.g. from JSON
  end
end

plugin :column, serializer: MyDataSerializer
```

Some serialization libraries such as [Oj] and [MessagePack] already implement
this interface, which simplifies the configuration:

```rb
require "oj" # https://github.com/ohler55/oj

plugin :column, serializer: Oj
```

If you want to disable serialization and work with hashes directly, you can set
`:serializer` to `nil`:

```rb
plugin :column, serializer: nil # disable serialization
```

The serializer can also be changed for a particular attacher instance:

```rb
Shrine::Attacher.new(column_serializer: Oj)  # use custom serializer
Shrine::Attacher.new(column_serializer: nil) # disable serialization
```

[column]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/column.rb
[model]: https://shrinerb.com/docs/plugins/model
[entity]: https://shrinerb.com/docs/plugins/entity
[Oj]: https://github.com/ohler55/oj
[MessagePack]: https://github.com/msgpack/msgpack-ruby
