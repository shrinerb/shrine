# included

The `included` plugin allows you to hook up to the `.included` hook of the
attachment module, and call additional methods on the model which includes it.

```rb
plugin :included do |name|
  before_save do
    # ...
  end
end
```

If you want to define additional methods on the model, it's recommended to use
the `module_include` plugin instead.
