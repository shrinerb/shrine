## HEAD

* Fix having the ability to promote the same attachment multiple times with backgrounding (janko-m)

* Fix recache plugin causing an infinite loop (janko-m)

* Fix an encoding error in determine_mime_type when using `:file` with non-files (janko-m)

* Make `UploadedFile` actually delete itself only once (janko-m)

* Make `UploadedFile#inspect` cleaner by showing only the data hash (janko-m)

* Make determine_mime_type able to accept non-files when using :file (janko-m)

* Make logging plugin accept PORO instance which don't have an #id (janko-m)

* Add rack_file plugin for attaching Rack file hashes to models (janko-m)
