## HEAD

* Add `:metadata` option to `Shrine#upload` for manually overriding extracted metadata (@janko-m)

* Add `:force` option to `infer_extension` plugin for always replacing the current extension (@jrochkind)

* Add `:public` option to `S3#initialize` for enabling public uploads (@janko-m)

* Add ability to specify a custom `:signer` for `Shrine::Storage::S3#url` (@janko-m)

* In `S3#upload` do multipart upload for large non-file IO objects (@janko-m)

* In `S3#upload` switch to `Aws::S3::Object#upload_stream` for multipart uploads of IO objects of unknown size (@janko-m)

* In `S3#upload` deprecate using aws-sdk-s3 lower than 1.14 when uploading IO objects of unknown size (@janko-m)

## 2.12.0 (2018-08-22)

* Ignore nil values when assigning files from a remote URL (@janko-m)

* Ignore nil values when assigning files from a data URI (@GeekOnCoffee)

* Raise `Shrine::Error` when child process failed to be spawned in `:file` MIME type analyzer (@hmistry)

* Use the appropriate unit in error messages of filesize validators in `validation_helpers` plugin (@hmistry)

* Fix subclassing not inheriting storage resolvers from superclass in `dynamic_storage` plugin (@janko-m)

* Un-deprecate assigning cached versions (@janko-m)

* Add `Attacher#assign_remote_url` which allows dynamically passing downloader options (@janko-m)

* Deprecate `:storages` option in `download_endpoint` plugin in favour of `UploadedFile#download_url` (@janko-m)

* Add `:redirect` option to `download_endpoint` plugin for redirecting to the uploaded file (@janko-m)

* Fix encoding issues when uploading IO object with unknown size to S3 (@janko-m)

* Accept additional `File.open` arguments in `FileSystem#open` (@janko-m)

* Add `:rewindable` option to `S3#open` for disabling caching of read content to disk (@janko-m)

* Make `UploadedFile#open` always open a new IO object and close the previous one (@janko-m)

## 2.11.0 (2018-04-28)

* Add `Shrine.with_file` for temporarily converting an IO-like object into a file (@janko-m)

* Add `:method` value to the `S3#presign` result indicating the HTTP verb that should be used (@janko-m)

* Add ability to specify `method: :put` in `S3#presign` to generate data for PUT upload (@janko-m)

* Return a `Struct` instead of a `Aws::S3::PresignedPost` object in `S3#presign` (@janko-m)

* Deprecate `Storage#presign` returning a custom object in `presign_endpoint` (@janko-m)

* Allow `Storage#presign` to return a Hash in `presign_endpoint` (@janko-m)

* Add ability to specify upload checksum in `upload_endpoint` plugin (@janko-m)

* Don't raise exception in `:mini_magick` and `:ruby_vips` dimensions analyzers when image is invalid (@janko-m)

* Don't remove bucket name from S3 URL path with `:host` when `:force_path_style` is set (@janko-m)

* Correctly determine MIME type from extension of empty files (@janko-m)

* Modify `UploadedFile#download` not to reopen the uploaded file if it's already open (@janko-m)

* Add `UploadedFile#stream` for streaming content into a writable object (@janko-m)

* Deprecate `direct_upload` plugin in favor of `upload_endpoint` and `presign_endpoint` plugins (@janko-m)

## 2.10.0 (2018-03-28)

* Add `:fastimage` analyzer to `determine_mime_type` plugin (@mokolabs)

* Keep download endpoint URL the same regardless of metadata ordering (@MSchmidt)

* Remove `:rack_mime` extension inferrer from the `infer_extension` plugin (@janko-m)

* Allow `UploadedFile#download` to accept a block for temporary file download (@janko-m)

* Add `:ruby_vips` analyzer to `store_dimensions` plugin (@janko-m)

* Add `:mini_magick` analyzer to `store_dimensions` plugin (@janko-m)

* Soft-rename `:heroku` logging format to `:logfmt` (@janko-m)

* Deprecate `Shrine::IO_METHODS` constant (@janko-m)

* Don't require IO size to be known on upload (@janko-m)

* Inherit the logger on subclassing `Shrine` and make it shared across subclasses (@hmistry)

## 2.9.0 (2018-01-27)

* Support arrays of files in `versions` plugin (@janko-m)

* Added `:marcel` analyzer to `determine_mime_type` plugin (@janko-m)

* Deprecate `:filename` option of the `data_uri` plugin in favour of the new `infer_extension` plugin (@janko-m)

* Add `infer_extension` plugin for automatically deducing upload location extension from MIME type (@janko-m)

* Apply default storage options passed via `Attachment.new` in `backgrounding` plugin (@janko-m)

* Fix S3 storage replacing spaces in filename with "+" symbols (@ndbroadbent)

* Deprecate the `multi_delete` plugin (@janko-m)

* Allow calling `UploadedFile#open` without passing a block (@hmistry)

* Delete tempfiles in case of errors in `UploadedFile#download` and `Storage::S3#download` (@hmistry)

* Freeze all string literals (@hmistry)

* Allow passing options to `Model#<attachment>_attacher` for overriding `Attacher` options (@janko-m)

## 2.8.0 (2017-10-11)

* Expand relative directory paths when initializing `Storage::FileSystem` (@janko-m)

* Fix `logging` plugin erroring on `:json` format when ActiveSupport is loaded (@janko-m)

* Allow `Storage::S3#clear!` to take a block for specifying which objects to delete (@janko-m)

* Make `:filemagic` analyzer close the FileMagic descriptor even in case of exceptions (@janko-m)

* Make `:file` analyzer work for potential file types which have magic bytes farther than 256 KB (@janko-m)

* Deprecate `aws-sdk` 2.x in favour of the new `aws-sdk-s3` gem (@janko-m)

* Modify `UploadedFile#extension` to always return the extension in lowercase format (@janko-m)

* Downcase the original file extension when generating an upload location (@janko-m)

* Allow specifying the full record attribute name in `metadata_attributes` plugin (@janko-m)

* Allow specifying metadata mappings on `metadata_attributes` plugin initialization (@janko-m)

* Add support for ranged requests in `download_endpoint` and `rack_response` plugins (@janko-m)

* Allow `Storage::S3#open` and `Storage::S3#download` to accept additional options (@janko-m)

* Forward any options given to `UploadedFile#open` or `UploadedFile#download` to the storage (@janko-m)

* Update `direct_upload` plugin to support Roda 3 (@janko-m)

## 2.7.0 (2017-09-11)

* Deprecate the `Shrine::DownloadEndpoint` constant over `Shrine.download_endpoint` (@janko-m)

* Allow an additional `#headers` attribute on presigns and return it in `presign_endpoint` (@janko-m)

* Allow overriding `upload_endpoint` and `presign_endpoint` options per-endpoint (@janko-m)

* Add `:presign` and `:rack_response` options to `presign_endpoint` (@janko-m)

* Add `:upload`, `:upload_context` and `:rack_response` options to `upload_endpoint` (@janko-m)

* Modify `upload_endpoint` and `presign_endpoint` to return `text/plain` error responses (@janko-m)

* Add `:request` upload context parameter in `upload_endpoint` (@janko-m)

* Change `:action` upload context parameter to `:upload` in `upload_endpoint` (@janko-m)

* Return `405 Method Not Allowed` on invalid HTTP verb in `upload_endpoint` and `presign_endpoint` (@janko-m)

* Modify `upload_endpoint` and `presign_endpoint` to handle requests on the root URL (@janko-m)

* Allow creating Rack apps dynamically in `upload_endpoint` and `presign_endpoint` (@janko-m)

* Remove Roda dependency from `upload_endpoint` and `presign_endpoint` plugins (@janko-m)

* Split `direct_upload` plugin into `upload_endpoint` and `presign_endpoint` plugins (@janko-m)

* Support the new `aws-sdk-s3` gem in `Shrine::Storage::S3` (@lizdeika)

* Return `Cache-Control` header in `download_endpoint` to permanently cache responses (@janko-m)

* Return `404 Not Found` when uploaded file doesn't exist in `download_endpoint` (@janko-m)

* Utilize uploaded file metadata when generating response in `download_endpoint` (@janko-m)

* Fix deprecation warning when generating fake presign with query parameters (@janko-m)

* Don't raise error in `file` and `filemagic` MIME type analyzer on empty IO (@ypresto)

* Require `down` in `remote_url` plugin even when a custom downloader is given (@janko-m)

* Require `time` library in `logging` plugin to fix `undefined method #iso8601 for Time` (@janko-m)

* Allow validations defined on a superclass to be reused in a subclass (@printercu)

* Allow validation error messages to be an array of arguments for ActiveRecord (@janko-m)

* Allow model subclasses to override the attachment with a different uploader (@janko-m)

* Accept `Attacher.new` options like `store:` and `cache:` via `Attachment.new` (@ypresto)

* Raise `ArgumentError` when `:bucket` option is nil in `Shrine::Storage::S3#initialize` (@janko-m)

* Don't wrap base64-encoded content into 60 columns in `UploadedFile#base64` and `#data_uri` (@janko-m)

* Add `:mini_mime` option to `determine_mime_type` plugin for using the [mini_mime](https://github.com/discourse/mini_mime) gem (@janko-m)

* Fix `data_uri` plugin raising an exception on Ruby 2.4.1 when using raw data URIs (@janko-m)

* Implement `Shrine::Storage::S3#open` using the aws-sdk gem instead of `Down.open` (@janko-m)

* Un-deprecate `Shrine.uploaded_file` accepting file data as JSON string (@janko-m)

* Don't wrap base64-formatted signatures to 60 columns (@janko-m)

* Don't add a newline at the end of the base64-formatted signature (@janko-m)

## 2.6.1 (2017-04-12)

* Fix `download_endpoint` returning incorrect reponse body in some cases (@janko-m)

## 2.6.0 (2017-04-04)

* Make `Shrine::Storage::FileSystem#path` public which returns path to the file as a `Pathname` object (@janko-m)

* Add `Shrine.rack_file` to `rack_file` plugin for converting Rack uploaded file hash into an IO (@janko-m)

* Deprecate passing a Rack file hash to `Shrine#upload` (@janko-m)

* Expose `Shrine.extract_dimensions` and `Shrine.dimensions_analyzers` in `store_dimensions` plugin (@janko-m)

* Add `metadata_attributes` plugin for syncing attachment metadata with additional record attributes (@janko-m)

* Remove the undocumented `:magic_header` option from `determine_mime_type` plugin (@janko-m)

* Expose `Shrine.determine_mime_type` and `Shrine.mime_type_analyzers` in `determine_mime_type` plugin (@janko-m)

* Add `signature` plugin for calculating a SHA{1,256,384,512}/MD5/CRC32 hash of a file (@janko-m)

* Return the resolved plugin module when calling `Shrine.plugin` (@janko-m)

* Accept hash of metadata with symbol keys as well in `add_metadata` block (@janko-m)

* Add `refresh_metadata` plugin for re-extracting metadata from an uploaded file (@janko-m)

* Allow S3 storage to use parallelized multipart upload for files from FileSystem storage as well (@janko-m)

* Improve default multipart copy threshold for S3 storage (@janko-m)

* Allow specifying multipart upload and copy thresholds separately in `Shrine::Storage::S3` (@janko-m)

* Fix `Storage::FileSystem#clear!` not deleting old files if there are newer files in the same directory (@janko-m)

* Allow media type in the data URI to have additional parameters (@janko-m)

* URI-decode non-base64 data URIs, as such data URIs are URI-encoded according to the specification (@janko-m)

* Improve performance of parsing data URIs by 10x switching from a regex to StringScanner (@janko-m)

* Reduce memory usage of `Shrine.data_uri` and `UploadedFile#base64` by at least 2x (@janko-m)

* Add `Shrine.data_uri` to `data_uri` plugin which parses and converts the given data URI to an IO object (@janko-m)

* Make `rack_file` plugin work with HashWithIndifferentAccess-like objects such as Hashie::Mash (@janko-m)

* Expose `Aws::S3::Client` via `Shrine::Storage::S3#client`, and deprecate `Shrine::Strorage::S3#s3` (@janko-m)

* Modify `delete_raw` plugin to delete any IOs that respond to `#path` (@janko-m)

* Require the Tempfile standard library in lib/shrine.rb (@janko-m)

* Deprecate dimensions validations passing when a dimension is nil (@janko-m)

* Deprecate passing regexes to type/extension whitelists/blacklists in `validation_helpers` (@janko-m)

* Don't include list of blacklisted types and extensions in default `validation_helpers` messages (@janko-m)

* Improve default error messages in `validation_helpers` plugin (@janko-m)

* Don't require the `benchmark` standard library in `logging` plugin (@janko-m)

* Don't dirty the attacher in `Attacher#set` when attachment hasn't changed (@janko-m)

* Rename `Attacher#attached?` to a more accurate `Attacher#changed?` (@janko-m)

* Allow calling `Attacher#finalize` if attachment hasn't changed, instead of raising an error (@janko-m)

* Make `Shrine::Storage::S3#object` method public (@janko-m)

* Prevent autoloading race conditions in aws-sdk gem by eager loading the S3 service (@janko-m)

* Raise `Shrine::Error` when `Shrine#generate_location` returns nil (@janko-m)

## 2.5.0 (2016-11-11)

* Add `Attacher.default_url` as the idiomatic way of declaring default URLs (@janko-m)

* Allow uploaders themselves to accept Rack uploaded files when `rack_file` is loaded (@janko-m)

* Raise a descriptive error when two versions are pointing to the same IO object (@janko-m)

* Make `backgrounding` plugin work with plain model instances (@janko-m)

* Make validation methods in `validation_helpers` plugin return whether validation succeeded (@janko-m)

* Make extension matching case insensitive in `validation_helpers` plugin (@jonasheinrich)

* Make `remove_invalid` plugin remove dirty state on attacher after removing invalid file (@janko-m)

* Raise error if `Shrine::UploadedFile` isn't initialized with valid data (@janko-m)

* Accept `extension` parameter without the dot in presign endpoint of `direct_upload` plugin (@jonasheinrich)

* Add `:fallback_to_original` option to `versions` plugin for disabling fallback to original file (@janko-m)

* Add `#dimensions` method to `UploadedFile` when loading `store_dimensions` plugin (@janko-m)

* Make it possible to extract multiple metadata values at once with the `add_metadata` plugin (@janko-m)

## 2.4.1 (2016-10-17)

* Move back JSON serialization from `Attacher#write` to `Attacher#_set` (@janko-m)

* Make `remove_invalid` plugin assign back a previous attachment if was there (@janko-m)

* Deprecate `Storage::FileSystem#download` (@janko-m)

* In `UploadedFile#download` use extension from `#original_filename` if `#id` doesn't have it (@janko-m)

## 2.4.0 (2016-10-11)

* Add `#convert_before_write` and `#convert_after_read` on the Attacher for data attribute conversion (@janko-m)

* Extract the `<attachment>_data` attribute name into `Attacher#data_attribute` (@janko-m)

* Support JSON and JSONB PostgreSQL columns with ActiveRecord (@janko-m)

* Fix S3 storage not handling filenames with double quotes in Content-Disposition header (@janko-m)

* Work around aws-sdk failing with non-ASCII characters in Content-Disposition header (@janko-m)

* Allow dynamically generating URL options in `default_url_options` plugin (@janko-m)

* Don't run file validations when duplicating the record in `copy` plugin (@janko-m)

* Don't use `Storage#stream` in download_endpoint plugin anymore, rely on `Storage#open` (@janko-m)

* Remove explicitly unlinking Tempfiles returned by `Storage#open` (@janko-m)

* Move `:host` from first-class storage option to `#url` option on FileSystem and S3 storage (@janko-m)

* Don't fail in FileSystem storage when attempting to delete a file that doesn't exist (@janko-m)

* In `UploadedFile#open` handle the case when `Storage#open` raises an error (@janko-m)

* Make the `sequel` plugin use less memory during transactions (@janko-m)

* Use Roda's streaming plugin in `download_endpoint` for better EventMachine integration (@janko-m)

* Deprecate accepting a JSON string in `Shrine.uploaded_file` (@janko-m)

* In S3 storage automatically write original filename to `Content-Disposition` header (@janko-m)

* Override `#to_s` in `Shrine::Attachment` for better introspection with `puts` (@janko-m)

## 2.3.1 (2016-09-01)

* Don't change permissions of existing directories in FileSystem storage (@janko-m)

## 2.3.0 (2016-08-27)

* Prevent client from caching the presign response in direct_upload plugin (@janko-m)

* Make Sequel update only the attachment in background job (@janko-m)

* Add copy plugin for copying files from one record to another (@janko-m)

* Disable moving when uploading stored file to backup storage (@janko-m)

* Make `Attacher#recache` from the recache plugin public for standalone usage (@janko-m)

* Allow changing `Shrine::Attacher#context` once the attacher is instantiated (@janko-m)

* Make `Attacher#read` for reading the attachment column public (@janko-m)

* Don't rely on the `#id` writer on a model instance in backgrounding plugin (@janko-m)

* Don't make `Attacher#swap` private in sequel and activerecord plugins (@janko-m)

* Set default UNIX permissions to 0644 for files and 0755 for directories (@janko-m)

* Apply directory permissions to all subfolders inside the main folder (@janko-m)

* Add `:directory_permissions` to `Storage::FileSystem` (@janko-m)

## 2.2.0 (2016-07-29)

* Soft deprecate `:phase` over `:action` in `context` (@janko-m)

* Add ability to sequel and activerecord plugins to disable callbacks and validations (@janko-m)

* The direct_upload endpoint now always includes both upload and presign routes (@janko-m)

* Don't let the combination for delete_raw and moving plugins trigger any errors (@janko-m)

* Add `UploadedFile#open` that mimics `File.open` with a block (@janko-m)

* In the storage linter don't require `#clear!` to be implemented (@janko-m)

* In backgrounding plugin don't require model to have attachment module included (@janko-m)

* Add add_metadata plugin for defining additional metadata values to be extracted (@janko-m)

* In determine_mime_type plugin raise error when file command wasn't found or errored (@janko-m)

* Add processing plugin for simpler and more declarative definition of processing (@janko-m)

* Storage classes don't need to implement the `#read` method anymore (@janko-m)

* Use aws-sdk in `S3#download`, which will automatically retry failed downloads (@janko-m)

* Add `:multipart_threshold` for when S3 storage should use parallelized multipart copy/upload (@janko-m)

* Automatically use optimized multipart S3 upload for files larger than 15MB (@janko-m)

* Avoid an additional HEAD request to determine content length in multipart S3 copy (@janko-m)

## 2.1.1 (2016-07-14)

* Fix `S3#open` throwing a NameError if `net/http` isn't required (@janko-m)

## 2.1.0 (2016-06-27)

* Remove `:names` from versions plugin, and deprecate generating versions in :cache phase (@janko-m)

* Pass a `Shrine::UploadedFile` in restore_cached_data instead of the raw IO (@janko-m)

* Increase magic header length in determine_mime_type and make it configurable (@janko-m)

* Execute `file` command in determine_mime_type the same way for files as for general IOs (@janko-m)

* Make logging and parallelize plugins work properly when loaded in this order (@janko-m)

* Don't assert arity of IO methods, so that objects like `Rack::Test::UploadedFile` are allowed (@janko-m)

* Deprecate `#cached_<attachment>_data=` over using `<attachment>` for the hidden field (@janko-m)

## 2.0.1 (2016-05-30)

* Don't override previously set default_url in versions plugin (@janko-m)

## 2.0.0 (2016-05-19)

* Include query parameters in CDN-ed S3 URLs, making them work for private objects (@janko-m)

* Remove the `:include_error` option from remote_url plugin (@janko-m)

* Make previous plugin options persist when reapplying the plugin (@janko-m)

* Improve how upload options and metadata are passed to storage's `#upload` and `#move` (@janko-m)

* Remove `Shrine::Confirm` and confirming `Storage#clear!` in general (@janko-m)

* Allow implementing a custom dimensions analyzer using built-in ones (@janko-m)

* Don't error in determine_mime_type when MimeMagic cannot determine the MIME (@janko-m)

* Allow implementing a custom MIME type analyzer using built-in ones (@janko-m)

* Don't check that the cached file exists in restore_cached_data plugin (@janko-m)

* Deprecate migration_helpers plugin and move `Attacher#cached?` and `Attacher#stored?` to base (@janko-m)

* Don't trigger restore_cached_data plugin functionality when assigning the same cached attachment (@janko-m)

* Give `Attacher#_promote` and `Attacher#promote` the same method signature (@janko-m)

* Add `Attacher#_delete` which now spawns a background job instead of `Attacher#delete!` (@janko-m)

* Make `Attacher#cache!`, `Attacher#store!`, and `Attacher#delete!` public (@janko-m)

* Don't cache storages in dynamic_storage plugin (@janko-m)

* Make only one HTTP request in download_endpoint plugin (@janko-m)

* Print secuity warning when not using determine_mime_type plugin (@janko-m)

* Support Mongoid in backgrounding plugin (@janko-m)

* Allow including attachment module to non-`Sequel::Model` objects in sequel plugin (@janko-m)

* Handle paths that start with "-" in determine_mime_type plugin when `:file` analyzer is used (@zaeleus)

* Allow including attachment module to non-`ActiveRecord::Base` objects in activerecord plugin (@janko-m)

* Remove deprecated "restore_cached" alias for restore_cached_data plugin (@janko-m)

* Remove deprecated "delete_uploaded" alias for delete_raw plugin (@janko-m)

* Make the default generated unique location shorter (@janko-m)

* Make the `:delegate` option in migration_helpers default to `false` (@janko-m)

* Don't require `:storages` option anymore in moving plugin (@janko-m)

* Don't delete uploaded IO if storage doesn't support moving in moving plugin (@janko-m)

* Rename delete phases to be shorter and consistent in naming with upload phases (@janko-m)

* Remove deprecated `Shrine#default_url` (@janko-m)

* Remove deprecated `:subdirectory` on FileSystem storage (@janko-m)

* Don't return the uploaded file in `Attacher#set` and `Attacher#assign` (@janko-m)

* Return the attacher instance in `Attacher.promote` and `Attacher.delete` in backgrounding plugin (@janko-m)

* Rename "attachment" to "name", and "uploaded_file" to "attachment" in backgrounding plugin (@janko-m)

* Remove using `:presign` for presign options instead of `:presign_options` (@janko-m)

* Remove deprecated `Shrine.direct_endpoint` from direct_upload plugin (@janko-m)

* Remove deprecated keep_location plugin (@janko-m)

* Make `Shrine#extract_dimensions` a private method in store_dimensions plugin (@janko-m)

* Keep `Shrine#extract_mime_type` a private method when loading determine_mime_type plugin (@janko-m)

* Deprecate loading the backgrounding plugin through the old "background_helpers" alias (@janko-m)

## 1.4.2 (2016-04-19)

* Removed ActiveRecord's automatic support for optimistic locking as it wasn't stable (@janko-m)

* Fixed record's dataset being modified after promoting preventing further updates with the same instance (@janko-m)

## 1.4.1 (2016-04-18)

* Bring back triggering callbacks on promote in ORM plugins, and add support for optimistic locking (@janko-m)

## 1.4.0 (2016-04-15)

* Return "Content-Length" response header in download_endpoint plugin (@janko-m)

* Make determine_mime_type and store_dimensions automatically rewind IO with custom analyzer (@janko-m)

* Make `before_*` and `after_*` hooks happen before and after `around_*` hooks (@janko-m)

* Rename restore_cached plugin to more accurate "restore_cached_data" (@janko-m)

* Prevent errors when attempting to validate dimensions when they are absent (@janko-m)

* Remove "thread" gem dependency in parallelize plugin (@janko-m)

* Add `:filename` to data_uri plugin for generating filenames based on content type (@janko-m)

* Make user-defined hooks always happen around logging (@janko-m)

* Add `:presign_location` to direct_upload for generating the key (@janko-m)

* Add separate `:presign_options` option for receiving presign options in direct_upload plugin (@janko-m)

* Add ability to generate fake presigns for storages which don't support them for testing (@janko-m)

* Change the `/:storage/:name` route to `/:storage/upload` in direct_upload plugin (@janko-m)

* Fix logger not being inherited in the logging plugin (@janko-m)

* Add delete_promoted plugin for deleting promoted files after record has been updated (@janko-m)

* Allow passing phase to `Attacher#promote` and generalize promoting background job (@janko-m)

* Close the cached file after extracting its metadata in restore_cached plugin (@janko-m)

* Rename delete_uploaded plugin to "delete_raw" to better explain its functionality (@janko-m)

* Pass the SSL CA bundle to open-uri when downloading an S3 file (@janko-m)

* Add `Attacher.dump` and `Attacher.load` for writing custom background jobs with custom functionality (@janko-m)

* Fix S3 URL erroring due to not being URL-encoded when `:host` option is used (@janko-m)

* Remove a tiny possibility of a race condition with backgrounding on subsequent updates (@janko-m)

* Add `:delegate` option to migration_helpers for opting out of defining methods on the model (@janko-m)

* Make logging plugin log number of both input and output files for processing (@janko-m)

* Make deleting backup work with backgrounding plugin (@janko-m)

* Make storing backup happen *after* promoting instead of before (@janko-m)

* Add `:fallbacks` to versions plugin for fallback URLs for versions which haven't finished processing (@janko-m)

* Fix keep_files not to spawn a background job when file will not be deleted (@janko-m)

## 1.3.0 (2016-03-12)

* Add `<attachment>_cached?` and `<attachment>_stored?` to migration_helpers plugin (@janko-m)

* Fix `Attacher#backup_file` from backup plugin not to modify the given uploaded file (@janko-m)

* Allow modifying UploadedFile's data hash after it's instantiated to change the UploadedFile (@janko-m)

* Deprecate the keep_location plugin (@janko-m)

* Don't mutate context hash inside the uploader (@janko-m)

* Make extracted metadata accessible in `#generate_location` through `:metadata` in context hash (@janko-m)

* Don't require the "metadata" key when instantiating a `Shrine::UploadedFile` (@janko-m)

* Add `:include_error` option to remote_url for accessing download error in `:error_message` block (@janko-m)

* Give different error message when file wasn't found or was too large in remote_url (@janko-m)

* Rewind the IO after extracting MIME type with MimeMagic (@janko-m)

* Rewind the IO after extracting image dimensions even when extraction failed (@kaapa)

* Correctly infer the extension in `#generate_location` when uploading an `UploadedFile` (@janko-m)

* Fix ability for errors to accumulate in data_uri and remote_url plugins when assigning mutliples to same record instance (@janko-m)

* Bump Down dependency to 2.0.0 in order to fix downloading URLs with "[]" characters (@janko-m)

* Add `:namespace` option to pretty_location for including class namespace in location (@janko-m)

* Don't include the namespace of the class in the location with the pretty_location plugin (@janko-m)

* Remove aws-sdk deprecation warning when storage isn't instantiated with credentials (@reidab)

* Don't make uploaded file's metadata methods error when the corresponding key-value pair is missing (@janko-m)

* Close the `UploadedFile` on upload only if it was previously opened, which doesn't happen on S3 COPY (@reidab)

* Fix `NameError` when silencing "missing record" errors in backgrounding (@janko-m)

## 1.2.0 (2016-01-26)

* Make `Shrine::Attacher.promote` and `Shrine::Attacher.delete` return the record in backgrounding plugin (@janko-m)

* Close the IO on upload even if the upload errors (@janko-m)

* Use a transaction when checking if attachment has changed after storing during promotion (@janko-m)

* Don't attempt to start promoting in background if attachment has already changed (@janko-m)

* Don't error in backgrounding when record is missing (@janko-m)

* Prevent multiline content type spoof attempts in validation_helpers (@xzo)

* Make custom metadata inherited from uploaded files and make `#extract_metadata` called only on caching (@janko-m)

## 1.1.0 (2015-12-26)

* Rename the "background_helpers" plugin to "backgrounding" (@janko-m)

* Rename the `:subdirectory` option to `:prefix` on FileSystem storage (@janko-m)

* Add download_endpoint plugin for downloading files uploaded to database storages and for securing downloads (@janko-m)

* Make `around_*` hooks return the result of the corresponding action (@janko-m)

* Make the direct upload endpoint customizable, inheritable and inspectable (@janko-m)

* Add upload_options plugin for dynamically generating storage-specific upload options (@janko-m)

* Allow the context hash to be modified (@janko-m)

* Fix extension not being returned for storages which remove it from ID (Flickr, SQL, GridFS) (@janko-m)

* Delete underlying Tempfiles when closing an `UploadedFile` (@janko-m)

* Fix background_helpers plugin not working with ActiveJob (@janko-m)

* Add `UploadedFile#base64` to the data_uri plugin (@janko-m)

* Optimize `UploadedData#data_uri` to not download the file and instantiate file contents string only once (@janko-m)

* Allow adding S3 upload options dynamically per upload (@janko-m)

* Add delete_uploaded plugin for automatically deleting files after they're uploaded (@janko-m)

* Close an open file descriptor left after downloading a FileSystem file (@janko-m)

* Make `FileSystem#url` Windows compatible (@janko-m)

* Add `UploadedFile#content_type` alias to `#mime_type` for better integration with upload libraries (@janko-m)

* Add a `UploadedFile#data_uri` method to the data_uri plugin (@janko-m)

* Allow the data_uri plugin to accept "+" symbols in MIME type names (@janko-m)

* Make the data_uri plugin accept data URIs which aren't base64 encoded (@janko-m)

* Close all IOs after uploading them (@janko-m)

* Allow passing a custom IO object to the Linter (@janko-m)

* Add remove_invalid plugin for automatically deleting and deassigning invalid cached files (@janko-m)

* Add `:max_size` option to the direct_upload plugin (@janko-m)

* Move `Shrine#default_url` to default_url plugin (@janko-m)

* Enable `S3#multi_delete` to delete more than 1000 objects by batching deletes (@janko-m)

* Add the keep_location plugin for easier debugging or backups (@janko-m)

* Add the backup plugin for backing up stored files (@janko-m)

* Storages don't need to rewind the files after upload anymore (@janko-m)

* Make S3 presigns work when the `:endpoint` option is given (@NetsoftHoldings)

* Fix parallelize plugin to always work with the moving plugin (@janko-m)

* Fix S3 storage to handle copying files that are larger than 5GB (@janko-m)

* Add `:upload_options` to S3 storage for applying additional options on upload (@janko-m)

* Reduce length of URLs generated with pretty_location plugin (@gshaw)

## 1.0.0 (2015-11-27)

* Improve Windows compatibility in the FileSystem storage (@janko-m)

* Remove the ability for FileSystem storage to accept IDs starting with a slash (@janko-m)

* Fix keep_files plugin requiring context for deleting files (@janko-m)

* Extract assigning cached files by parsed JSON into a parsed_json plugin (@janko-m)

* Add `(before|around|after)_upload` to the hooks plugin (@janko-m)

* Fix `S3#multi_delete` and `S3#clear!` not using the prefix (@janko-m)

* Add ability to pass presign options to storages in the direct_upload plugin (@janko-m)

* Remove `Shrine.io!` because it was actually meant to be only for internal use (@janko-m)

* Remove `Shrine.delete` because of redundancy (@janko-m)

* Add default_url_options plugin for specifiying default URL options for uploaded files (@janko-m)

* Add module_include plugin for easily extending core classes for given uploader (@janko-m)

* Add support for Sequel's Postgres JSON column support (@janko-m)

* Fix migration_helpers plugin not detecting when column changed (@janko-m)

* Add the `:public` option to S3 storage for retrieving public URLs which aren't signed (@janko-m)

* Remove the delete_invalid plugin, as it could cause lame errors (@janko-m)

* Don't delete cached files anymore, as it can cause errors with backgrounding (@janko-m)

* Add a `:host` option to the S3 storage for specifying CDNs (@janko-m)

* Don't allow same attachment to be promoted multiple times with backgrounding (@janko-m)

* Fix recache plugin causing an infinite loop (@janko-m)

* Fix an encoding error in determine_mime_type when using `:file` with non-files (@janko-m)

* Make `UploadedFile` actually delete itself only once (@janko-m)

* Make `UploadedFile#inspect` cleaner by showing only the data hash (@janko-m)

* Make determine_mime_type able to accept non-files when using :file (@janko-m)

* Make logging plugin accept PORO instance which don't have an #id (@janko-m)

* Add rack_file plugin for attaching Rack file hashes to models (@janko-m)
