# Logging

The [`logging`][logging] plugin logs any storing/processing/deleting that is
performed.

```rb
plugin :logging
```

This plugin is useful when you want to have overview of what exactly is going
on, or you simply want to have it logged for future debugging. By default the
logging output looks something like this:

```
2015-10-09T20:06:06.676Z #25602: STORE[cache] ImageUploader[:avatar] User[29543] 1 file (0.1s)
2015-10-09T20:06:06.854Z #25602: PROCESS[store]: ImageUploader[:avatar] User[29543] 1-3 files (0.22s)
2015-10-09T20:06:07.133Z #25602: DELETE[destroyed]: ImageUploader[:avatar] User[29543] 3 files (0.07s)
```

The plugin accepts the following options:

| Option    | Description                                                                                                                                                                                    |
| :-------- | :----------                                                                                                                                                                                    |
| `:format` | This allows you to change the logging output into something that may be easier to grep. Accepts `:human` (default), `:json` and `:logfmt`.                                                     |
| `:stream` | The default logging stream is `$stdout`, but you may want to change it, e.g. if you log into a file. This option is passed directly to `Logger.new` (from the "logger" Ruby standard library). |
| `:logger` | This allows you to change the logger entirely. This is useful for example in Rails applications, where you might want to assign this option to `Rails.logger`.                                 |

The default format is probably easiest to read, but may not be easiest to grep.
If this is important to you, you can switch to another format:

```rb
plugin :logging, format: :json
# {"action":"upload","phase":"cache","uploader":"ImageUploader","attachment":"avatar",...}

plugin :logging, format: :logfmt
# action=upload phase=cache uploader=ImageUploader attachment=avatar record_class=User ...
```

Logging is by default disabled in tests, but you can enable it by setting
`Shrine.logger.level = Logger::INFO`.

[logging]: /lib/shrine/plugins/logging.rb
