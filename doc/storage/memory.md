---
title: Memory
---

The Memory storage stores uploaded files in memory, which is suitable for
testing.

```rb
Shrine.storages[:store] = Shrine::Storage::Memory.new
```

By default, each storage instance uses a new Hash object for storing files,
but you can pass your own:

```rb
my_store = Hash.new

Shrine.storages[:store] = Shrine::Storage::Memory.new(my_store)
```
