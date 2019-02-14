# Parallelize

The [`parallelize`][parallelize] plugin parallelizes uploads and deletes of
multiple versions using threads.

```rb
plugin :parallelize
```

By default a pool of 3 threads will be used, but you can change that:

```rb
plugin :parallelize, threads: 5
```

[parallelize]: /lib/shrine/plugins/parallelize.rb
