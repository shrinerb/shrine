# Pretty Location

The `pretty_location` plugin attempts to generate a nicer folder structure for
uploaded files.

```rb
plugin :pretty_location
```

This plugin uses the context information from the Attacher to try to generate a
nested folder structure which separates files for each record. The newly
generated locations will typically look like this:

```rb
"user/564/avatar/thumb-493g82jf23.jpg"
# :model/:id/:attachment/:version-:uid.:extension
```

By default if a record class is inside a namespace, only the "inner" class name
is used in the location. If you want to include the namespace, you can pass in
the `:namespace` option with the desired separator as the value:

```rb
plugin :pretty_location, namespace: "_"
# "blog_user/.../493g82jf23.jpg"

plugin :pretty_location, namespace: "/"
# "blog/user/.../493g82jf23.jpg"
```
