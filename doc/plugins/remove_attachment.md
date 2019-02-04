# remove_attachment

The `remove_attachment` plugin allows you to delete attachments through
checkboxes on the web form.

```rb
plugin :remove_attachment
```

If for example your attachment is called "avatar", this plugin will add
`#remove_avatar` and `#remove_avatar=` methods to your model. This allows you
to add a form field for removing attachments:

```rb
form.check_box :remove_avatar
```
