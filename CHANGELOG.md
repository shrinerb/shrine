## HEAD

* Rewind the IO after extracting image dimensions even when extraction failed (kaapa)

* Correctly infer the extension in `#generate_location` when uploading an `UploadedFile` (janko-m)

* Fix ability for errors to accumulate in data_uri and remote_url plugins when assigning mutliples to same record instance (janko-m)

* Bump Down dependency to 2.0.0 in order to fix downloading URLs with "[]" characters (janko-m)

* Add `:namespace` option to pretty_location for including class namespace in location (janko-m)

* Don't include the namespace of the class in the location with the pretty_location plugin (janko-m)

* Remove aws-sdk deprecation warning when storage isn't instantiated with credentials (reidab)

* Don't make uploaded file's metadata methods error when the corresponding key-value pair is missing (janko-m)

* Close the `UploadedFile` on upload only if it was previously opened, which doesn't happen on S3 COPY (reidab)

* Fix `NameError` when silencing "missing record" errors in backgrounding (janko-m)

## 1.2.0 (2016-01-26)

* Make `Shrine::Attacher.promote` and `Shrine::Attacher.delete` return the record in backgrounding plugin (janko-m)

* Close the IO on upload even if the upload errors (janko-m)

* Use a transaction when checking if attachment has changed after storing during promotion (janko-m)

* Don't attempt to start promoting in background if attachment has already changed (janko-m)

* Don't error in backgrounding when record is missing (janko-m)

* Prevent multiline content type spoof attempts in validation_helpers (xzo)

* Make custom metadata inherited from uploaded files and make `#extract_metadata` called only on caching (janko-m)

## 1.1.0 (2015-12-26)

* Rename the "background_helpers" plugin to "backgrounding" (janko-m)

* Rename the `:subdirectory` option to `:prefix` on FileSystem storage (janko-m)

* Add download_endpoint plugin for downloading files uploaded to database storages and for securing downloads (janko-m)

* Make `around_*` hooks return the result of the corresponding action (janko-m)

* Make the direct upload endpoint customizable, inheritable and inspectable (janko-m)

* Add upload_options plugin for dynamically generating storage-specific upload options (janko-m)

* Allow the context hash to be modified (janko-m)

* Fix extension not being returned for storages which remove it from ID (Flickr, SQL, GridFS) (janko-m)

* Delete underlying Tempfiles when closing an `UploadedFile` (janko-m)

* Fix background_helpers plugin not working with ActiveJob (janko-m)

* Add `UploadedFile#base64` to the data_uri plugin (janko-m)

* Optimize `UploadedData#data_uri` to not download the file and instantiate file contents string only once (janko-m)

* Allow adding S3 upload options dynamically per upload (janko-m)

* Add delete_uploaded plugin for automatically deleting files after they're uploaded (janko-m)

* Close an open file descriptor left after downloading a FileSystem file (janko-m)

* Make `FileSystem#url` Windows compatible (janko-m)

* Add `UploadedFile#content_type` alias to `#mime_type` for better integration with upload libraries (janko-m)

* Add a `UploadedFile#data_uri` method to the data_uri plugin (janko-m)

* Allow the data_uri plugin to accept "+" symbols in MIME type names (janko-m)

* Make the data_uri plugin accept data URIs which aren't base64 encoded (janko-m)

* Close all IOs after uploading them (janko-m)

* Allow passing a custom IO object to the Linter (janko-m)

* Add remove_invalid plugin for automatically deleting and deassigning invalid cached files (janko-m)

* Add `:max_size` option to the direct_upload plugin (janko-m)

* Move `Shrine#default_url` to default_url plugin (janko-m)

* Enable `S3#multi_delete` to delete more than 1000 objects by batching deletes (janko-m)

* Add the keep_location plugin for easier debugging or backups (janko-m)

* Add the backup plugin for backing up stored files (janko-m)

* Storages don't need to rewind the files after upload anymore (janko-m)

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
