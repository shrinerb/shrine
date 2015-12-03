## HEAD

* Make S3 presigns work when the `:endpoint` option is given (NetsoftHoldings)

* Fix parallelize plugin to always work with the moving plugin (janko-m)

* Fix S3 storage to handle copying files that are larger than 5GB (janko-m)

* Add `:upload_options` to S3 storage for applying additional options on upload (janko-m)

* Reduce length of URLs generated with pretty_location plugin (gshaw)

## 1.0.0 (2015-11-27)

* Improve Windows compatibility in the FileSystem storage (janko-m)

* Remove the ability for FileSystem storage to accept IDs starting with a slash (janko-m)

* Fix keep_files plugin requiring context for deleting files (janko-m)

* Extract assigning cached files by parsed JSON into a parsed_json plugin (janko-m)

* Add `(before|around|after)_upload` to the hooks plugin (janko-m)

* Fix `S3#multi_delete` and `S3#clear!` not using the prefix (janko-m)

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
