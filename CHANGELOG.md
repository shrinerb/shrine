## HEAD

* Add ability to pass presign options to storages in the direct_upload plugin (janko-m)

* Remove `Shrine.io!` because it was actually meant to be only for internal use (janko-m)

* Remove `Shrine.delete` because of redundancy (janko-m)

* Add default_url_options plugin for specifiying default URL options for uploaded files (janko-m)

* Add module_include plugin for easily extending core classes for given uploader (janko-m)

* Add support for Sequel's Postgres JSON column support (janko-m)

* Fix migration_helpers plugin not detecting when column changed (janko-m)

* Add the `:public` option to S3 storage for retrieving public URLs which aren't signed (janko-m)

* Remove the delete_invalid plugin, as it could cause lame errors (janko-m)

* Don't delete cached files anymore, as it can cause errors with backgrounding (janko-m)

* Add a `:host` option to the S3 storage for specifying CDNs (janko-m)

* Don't allow same attachment to be promoted multiple times with backgrounding (janko-m)

* Fix recache plugin causing an infinite loop (janko-m)

* Fix an encoding error in determine_mime_type when using `:file` with non-files (janko-m)

* Make `UploadedFile` actually delete itself only once (janko-m)

* Make `UploadedFile#inspect` cleaner by showing only the data hash (janko-m)

* Make determine_mime_type able to accept non-files when using :file (janko-m)

* Make logging plugin accept PORO instance which don't have an #id (janko-m)

* Add rack_file plugin for attaching Rack file hashes to models (janko-m)
