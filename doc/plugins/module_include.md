# module_include

The `module_include` plugin allows you to extend Shrine's core classes for the
given uploader with modules/methods.

```rb
plugin :module_include
```

To add a module to a core class, call the appropriate method:

```rb
attachment_module CustomAttachmentMethods
attacher_module CustomAttacherMethods
file_module CustomFileMethods
```

Alternatively you can pass in a block (which internally creates a module):

```rb
attachment_module do
  def included(model)
    super

    name = attachment_name

    define_method :"#{name}_size" do |version|
      attachment = send(name)
      if attachment.is_a?(Hash)
        attachment[version].size
      elsif attachment
        attachment.size
      end
    end
  end
end
```

The above defines an additional `#<attachment>_size` method on the attachment
module, which is what is included in your model.
