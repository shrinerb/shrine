## Unreleased

* `download_endpoint` - Add support for expiring URLs

## 3.6.0 (2024-04-29)

* Add Rack 3 support (@tomasc, @janko)

* Make a copy of attacher context hash when duplicating the attacher (@reidab)

* An uploaded file can be implicitly re-opened after it has been closed (@jrochkind)

* Add new `:copy_options` for initializing the S3 storage (@hkdahal)

## 3.5.0 (2023-07-06)

* Migrate website to Docusaurus v2 (@janko)

* `download_endpoint` – Return `400 Bad Request` response when serialized file component is invalid (@janko)

* `base` – Stop using obsolete `URI.regexp` in `UploadedFile#extension` (@y-yagi)

* `s3` – Add `:encoding` option to `S3#open` to be passed to `Down::ChunkedIO#initialize` (@pond)

* `s3` – Add `:max_multipart_parts` option for changing default limit of 10,000 parts (@jpl)

* `s3` – Don't inherit S3 object tags when copying from temporary to permanent storage (@jrochkind)

* `infer_extension` – Add `infer_extension` instance method to the uploader for convenience (@aried3r)

* `derivation_endpoint` – Add `:signer` plugin option for providing a custom URL signer (@thibaudgg)

* `derivatives` – Don't leak `versions_compatibility: true` setting into other uploaders (@janko)

* `derivatives` – Add `:mutex` plugin option for skipping mutex and making attacher marshallable (@janko)

* `remove_attachment` – Fix passing boolean values being broken in Ruby 3.2 (@janko)

* `model` – When duplicating a record, make the duplicated attacher reference the duplicated record (@janko)

## 3.4.0 (2021-06-14)

* `base` – Fix passing options to `Shrine.Attachment` on Ruby 3.0 (@lucianghinda)

* `determine_mime_type` – Return correct `image/svg+xml` MIME type for SVGs with `:fastimage` analyzer (@Bandes)

* `activerecord` – Fix keyword argument warning when adding errors with options (@janko)

* `entity` – Make `Attacher#read` method public (@janko)

* `entity` – Reset attachment dirty tracking in `Attacher#reload` (@janko)

* `activerecord` – Don't load the attacher on `ActiveRecord::Base#reload` if it hasn't yet been initialized (@janko)

* `sequel` – Don't load the attacher on `Sequel::Model#reload` if it hasn't yet been initialized (@janko)

## 3.3.0 (2020-10-04)

* `s3` - Support new `Aws::S3::EncryptionV2::Client` for client-side encryption (@janko)

* `derivation_endpoint` – Reduce possibility of timing attacks when comparing signatures (@esparta)

* `derivatives` – Avoid downloading the attached file when calling default no-op processor (@janko)

* `derivatives` – Add `:download` processor setting for skipping downloading source file (@jrochkind, @janko)

* `derivatives` – Copy non-file source IO objects into local file before passing them to the processor (@jrochkind)

* `sequel` – Call `Attacher#reload` in `Sequel::Model#reload`, which keeps rest of attacher state (@janko, @jrochkind)

* `activerecord` – Call `Attacher#reload` in `ActiveRecord::Base#reload`, which keeps rest of attacher state (@janko, @jrochkind)

* `add_metadata` – Add `:skip_nil` option for excluding metadata keys whose values are nil (@renchap)

* `store_dimensions` – Add `:auto_extraction` option for disabling automatically extracting dimensions on upload (@renchap)

* `mirroring` – Forward original upload options when mirroring upload (@corneverbruggen)

* `derivation_endpoint` – Apply `version` URL option in derivation endpoint (@janko)

* `remove_attachment` – Delete removed file if a new file was attached right after removal (@janko)

* `upload_endpoint` – Fix `Shrine.upload_response` not working in a Rails controller (@pldavid2)

* `presign_endpoint` – Add `OPTIONS` route that newer versions of Uppy check (@janko)

* `derivatives` – Add `:create_on_promote` option for auto-creating derivatives on promotion (@janko)

* `s3` – Add back support for client-side encryption (@janko)

* `memory` – Ensure `Memory#open` returns content in original encoding (@jrochkind)

## 3.2.2 (2020-08-05)

* `s3` – Fix `S3#open` not working on aws-sdk-core 3.104 and above (@janko)

## 3.2.1 (2020-01-12)

* `derivation_endpoint` – Use `Rack::Files` constant on Rack >= 2.1 (@janko)

* Fix Ruby 2.7 warnings regarding separation of positional and keyword arguments (@janko)

* `s3` – Make `S3#open` handle empty S3 objects (@janko)

## 3.2.0 (2019-12-17) [[release notes]](https://shrinerb.com/docs/release_notes/3.2.0)

* `validation` – Run validation on `Attacher#attach` & `Attacher#attach_cached` instead of `Attacher#change` (@janko)

* `remove_invalid` – Activate also when `Attacher#validate` is run manually (@janko)

* `remove_invalid` – Fix incompatibility with `derivatives` plugin (@janko)

* `type_predicates` – Add new plugin with convenient `UploadedFile` predicate methods based on MIME type (@janko)

* `core` – Allow assigning back current attached file data (@janko)

* `derivatives` – Fix `:derivative` value inconsistency when derivatives are being promoted (@janko)

* `add_metadata` – Add `#add_metadata` method for adding metadata to uploaded files (@janko)

* `derivatives` – Add `:io` and `:attacher` values to instrumentation event payload (@janko)

## 3.1.0 (2019-11-15) [[release notes]](https://shrinerb.com/docs/release_notes/3.1.0)

* `default_storage` – Coerce storage key to symbol in `Attacher#cache_key` & `Attacher#store_key` (@janko)

* `core` – Coerce storage key to symbol in `Attacher#cache_key` & `Attacher#store_key` (@janko)

* `add_metadata` – Define metadata methods only for the target uploader class (@janko)

* `derivatives` – Add `:storage` option to `Attacher#create_derivatives` (@janko)

* `store_dimensions` – Propagate exceptions on loading `ruby-vips` in `:vips` analyzer (@janko)

* `signature` – Allow skipping rewinding by passing `rewind: false` to `Shrine.signature` (@janko)

* `derivatives` – Add `Attacher.derivatives` alias for `Attacher.derivatives_processor` (@janko)

## 3.0.1 (2019-10-17) [[release notes]](https://shrinerb.com/docs/release_notes/3.0.1)

* `metadata_attributes` – Fix exception being raised when there is no attached file (@janko)

* `core` – Simplify `UploadedFile#inspect` output (@janko)

## 3.0.0 (2019-10-14) [[release notes]](https://shrinerb.com/docs/release_notes/3.0.0)

* `derivation_endpoint` – Pass `action: :derivation` when uploading derivation results (@janko)

* `core` – Add `Shrine::Attachment[]` shorthand for `Shrine::Attachment.new` (@janko)

* `core` – Add `Storage#delete_prefixed` method for deleting all files in specified directory (@jrochkind)

* `linter` – Return `true` in `Storage::Linter#call` so that it can be used with `assert` (@jrochkind)

* `linter` – Allow `Storage::Linter` to accept a key that will be used for testing nonexistent file (@janko)

* `core` – Infer file extension from `filename` metadata (@janko)

* `pretty_location` – Add `:class_underscore` option for underscoring class name (@Uysim)

* Update `down` dependency to `~> 5.0` (@janko)

* `multi_cache` – Add new plugin for whitelisting additional temporary storages (@janko, @jrochkind)

* `sequel` – Extract callback code into attacher methods that can be overridden (@janko)

* `activerecord` – Extract callback code into attacher methods that can be overridden (@janko)

* `derivation_endpoint` – Stop re-opening `File` objects returned in derivation result (@janko)

* `derivation_endpoint` – Allow only `File` or `Tempfile` object as derivation result (@janko)

* `download_endpoint` – Add `Shrine.download_response` for calling in controller (@janko)

* `core` – Fetch storage object lazily in `Shrine` instance (@janko)

* `mirroring` – Add new plugin for replicating uploads and deletes to other storages (@janko)

* `sequel` – Rename `:callbacks` option to `:hooks` (@janko)

* `model` – Add `Attacher#set_model` for setting model without loading attachment (@janko)

* `entity` – Add `Attacher#set_entity` for setting entity without loading attachment (@janko)

* `entity` – Define `#<name>_attacher` class method when including `Shrine::Attachment` (@janko)

* `derivation_endpoint` – Send only `:derivation` in the instrumentation event payload (@janko)

* `default_storage` – Add `Attacher.default_cache` and `Attacher.default_store` for settings (@janko)

* `default_storage` – Deprecate `record` & `name` arguments to storage block (@janko)

* `default_storage` – Evaluate storage block in context of `Attacher` instance (@janko)

* Unify persistence plugin interface (@janko)

* `upload_options` – Keep `Shrine#_upload` private (@janko)

* `infer_extension` – Keep `Shrine#basic_location` private (@janko)

* `model` – Add `#<name>_changed?` method to attachment module (@janko)

* Make it easier for plugins to define entity and model attachment methods (@janko)

* `form_assign` – Add new plugin for assigning attachment from form params without a form object (@janko)

* `derivation_endpoint` – Allow passing generic IO objects to `Derivation#upload` (@janko)

* `derivation_endpoint` – Accept additional uploader options in `Derivation#upload` (@janko)

* `derivation_endpoint` – Close the uploaded file in `Derivation#upload` (@janko)

* `core` – Stop rescuing `IO#close` exceptions in `Shrine#upload` (@janko)

* `core` – Add `:delete` option to `Shrine#upload` for deleting uploaded file (@janko)

* `s3` – Stop returning `:object` in `Down::ChunkedIO#data` in `S3#open` (@janko)

* `s3` – Eliminate `#head_object` request in `S3#open` (@janko)

* `download_endpoint` – Remove extra `Storage#exists?` check (@janko)

* `derivation_endpoint` – Add `Derivation#opened` for retrieving an opened derivation result (@janko)

* `derivation_endpoint` – Remove extra `Storage#exists?` check when `:upload` is enabled but not `:upload_redirect` (@janko)

* `derivation_endpoint` - Don't pass source `UploadedFile` object when `:download` is `false` (@janko)

* `derivation_endpoint` – Remove `:include_uploaded_file` option (@janko)

* `derivation_endpoint` – Evaluate derivation block in context of `Shrine::Derivation` (@janko)

* `derivation_endpoint` – Remove `:download_errors` option (@janko)

* `memory` – Raise `Shrine::FileNotFound` on nonexistent file in `Memory#open` (@janko)

* `file_system` – Raise `Shrine::FileNotFound` on nonexistent file in `FileSystem#open` (@janko)

* `s3` – Raise `Shrine::FileNotFound` on nonexistent object in `S3#open` (@janko)

* `core` – Add `Shrine::FileNotFound` exception and require storages to raise it on `Storage#open` (janko)

* `instrumentation` – Remove `:metadata` from `:options` in `metadata.shrine` event (@janko)

* `instrumentation` – Remove `:location`, `:upload_options` and `:metadata` from `:options` in `upload.shrine` event (@janko)

* `instrumentation` – Add `:metadata` to the `upload.shrine` event (@janko)

* `download_endpoint` – Drop support for legacy `/:storage/:id` URLs (@janko)

* `core` – In `UploadedFile#==` require files to be of the same class (@janko)

* `core` – Add `:close` option to `Shrine#upload` for preventing closing file after upload (@janko)

* `memory` – Add `Shrine::Storage::Memory` from `shrine-memory` gem (@janko)

* `default_url_options` – Rename to just `url_options` (@janko)

* `delete_raw` – Deprecate plugin in favour of `derivatives` (@janko)

* `recache` – Deprecate plugin in favour of `derivatives` (@janko)

* `processing` – Deprecate plugin in favour of `derivatives` (@janko)

* `versions` – Deprecate plugin in favour of `derivatives` (@janko)

* `derivatives` – Add new plugin for storing processed files (@janko)

* `derivation_endpoint` – Allow using symbol and string derivation names interchangeably (@janko)

* `dynamic_storage` – Remove `Shrine.dynamic_storages` method (@janko)

* `core` – Deep duplicate `Shrine.opts` on subclassing (@janko)

* `core` – Add `Attacher#file!` which asserts that a file is attached (@janko)

* `core` – Change `Shrine.uploaded_file` to raise `ArgumentError` on invalid input (@janko)

* `module_include` – Deprecate plugin over overriding core classes directly (@janko)

* `core` – Add `Attacher#cache_key` and `Attacher#store_key` which return storage identifiers (@janko)

* `linter` – Call `Storage#open` with options as second argument (@janko)

* `core` – Allow data hash passed to `UploadedFile.new` to have symbol keys (@janko)

* `core` – Change how `Shrine::UploadedFile` sets its state from the given data hash (@janko)

* `core` – Deprecate `Storage#open` not accepting additional options (@janko)

* `refresh_metadata` – Add `Attacher#refresh_metadata!` method which integrates with `model` plugin (@janko)

* `instrumentation` – Instrument any `Storage#open` calls in a new `open.shrine` event (@janko)

* `restore_cached_data` – Forward options passed to `Attacher#attach_cached` to metadata extraction (@janko)

* `validation` – Allow skipping validations on attaching by passing `validate: false` (@janko)

* `validation` – Add `:validate` option to `Attacher#assign` or `Attacher#attach` for passing options to validation block (@janko)

* `validation` – Extract validation functionality into the new plugin (@janko)

* `upload_options` – Upload options from the block are now merged with passed options instead of replaced (@janko)

* `upload_endpoint` – Stop passing `Rack::Request` object to the uploader (@janko)

* `remote_url` – Require custom downloaders to raise `Shrine::Plugins::RemoteUrl::DownloadError` for conversion into a validation error (@janko)

* `infer_extension` – Fix compatibility with the `pretty_location` plugin (@janko)

* `presign_endpoint` – Remove deprecated `Shrine::Plugins::PresignEndpoint::App` constant (@janko)

* `keep_files` – Remove the ability to choose whether to keep only destroyed or only replaced files (@janko)

* `infer_extension` – Remove `Shrine#infer_extension` method (@janko)

* `default_url_options` – Allow overriding passed URL options by deleting them inside the block (@janko)

* `cached_attachment_data` – Rename `Attacher#read_cached` to `Attacher#cached_data` (@janko)

* `sequel` – Add `Attacher#atomic_promote` and `Attacher#atomic_persist` (@janko)

* `sequel` – Remove persistence from `Attacher#promote` (@janko)

* `activerecord` – Remove persistence from `Attacher#promote` (@janko)

* `atomic_helpers` – Add new plugin with helper methods for atomic promotion and persistence (@janko)

* `backgrounding` – Add `Attacher#promote_block` & `Attacher#destroy_block` for overriding class level blocks (@janko)

* `backgrounding` – Add `Attacher.promote_block` & `Attacher.destroy_block` on class level (@janko)

* `backgrounding` – Remove overriding `Attacher#swap` with atomic promotion (@janko)

* `backgrounding` – Remove `Attacher.promote`, `Attacher.delete`, `Attacher.dump`, `Attacher#dump`, `Attacher.load`, `Attacher.load_record` (@janko)

* `model` – Allow disabling caching to temporary storage on assignment (@janko)

* `model` – Add `Attacher.from_model`, `Attacher#write` (@janko)

* `model` – Add new plugin for integrating with mutable structs (@janko)

* `entity` – Add `Attacher.from_entity`, `Attacher#reload`, `Attacher#column_values`, `Attacher#attribute` (@janko)

* `entity` – Add new plugin for integrating with immutable structs (@janko)

* `column` – Allow changing column serializer from default `JSON` library (@janko)

* `column` – Add `Attacher#column_data` and `Attacher.from_column` methods (@janko)

* `column` – Add new plugin for (de)serializing attacher data (@janko)

* `attachment` – Removed any default attachment methods (@janko)

* `core` – Require context hash passed as second argument to `Shrine#upload` to have symbol keys (@janko)

* `core` – Change `Shrine.uploaded_file` not to yield files anymore (@janko)

* `core` – Allow `Shrine.uploaded_file` to accept file data hashes with symbol keys (@janko)

* `core` – Remove `Shrine#uploaded?`

* `core` – Remove `Shrine#delete`, `Shrine#_delete`, `Shrine#remove` (@janko)

* `core` – Remove `Shrine#store`, `Shrine#_store`, `Shrine#put`, `Shrine#copy` (@janko)

* `core` – Remove `Shrine#processed`, `Shrine#process` (@janko)

* `core` – Don't pass `:phase` anymore on uploads (@janko)

* `core` – Read attachment from the record attribute only on initialization (@janko)

* `core` – Don't require a temporary storage (@janko)

* `core` – Add `Attacher#data` and `Attacher.from_data` for dumping to and loading from a Hash (@janko)

* `core` – Change `Attacher#assign` to raise exception when non-cached file is assigned (@janko)

* `core` – Enable `Attacher#assign` to accept cached file data as a Hash (@janko)

* `core` – Add `Attacher#file` alias for `Attacher#get` (@janko)

* `core` – Change `Attacher#attached?` to return whether a file is attached (@janko)

* `core` – Change `Attacher#promote` to always only save promoted file in memory (@janko)

* `core` – Rename `Attacher#replace` to `Attacher#destroy_previous` (@janko)

* `core` – Remove `Attacher#_promote` and `Attacher#_delete`, add `Attacher#promote_cached` and `Attacher#destroy_attached` (@janko)

* `core` – Rename `Attacher#set` and `Attacher#_set` to `Attacher#change` and `Attacher#set` (@janko)

* `core` – Remove `Attacher#cache!` and `Attacher#store!`, add `Attacher#upload` (@janko)

* `core` – Rename `Attacher#validate_block` to `Attacher#_validate` (@janko)

* `core` – Add `Attacher#attach`, `Attacher#attach_cached`, extracted from `Attacher#assign` (@janko)

* `core` – Remove `Attacher#swap`, `Attacher#update`, `Attacher#read`, `Attacher#write`, `Attacher#data_attribute`, `Attacher#convert_to_data`, `Attacher#convert_before_write`, and `Attacher#convert_after_read` (@janko)

* `core` – Change `Attacher.new` to not accept a model anymore (@janko)

* `delete_promoted` – Remove plugin (@janko)

* `parsed_json` – Remove plugin (@janko)

* `parallelize` – Remove plugin (@janko)

* `hooks` – Remove plugin (@janko)

* `core` – Remove deprecated `Shrine::IO_METHODS` constant (@janko)

* `s3` – Replace source object metadata when copying a file from S3 (@janko)

* `core` – Change `UploadedFile#storage_key` to return a Symbol instead of a String (@janko)

* `infer_extension` – Make `:mini_mime` the default analyzer (@janko)

* Bring back Ruby 2.3 support (@janko)

* `versions` – Remove deprecated `:version_names`, `Shrine.version_names` and `Shrine.version?` (@janko)

* `validation_helpers` – Remove support for regexes in MIME type or extension validations (@janko)

* `validation_helpers` – Don't require `#width` and `#height` methods to be defined on `UploadedFile` (@janko)

* `validation_helpers` – Fail dimensions validations when `width` or `height` metadata is missing (@janko)

* `upload_endpoint` – Remove deprecated `Shrine::Plugins::UploadEndpoint::App` constant (@janko)

* `determine_mime_type` – Remove `Shrine#mime_type_analyzers` method (@janko)

* `store_dimensions` – Remove `Shrine#extract_dimensions` and `Shrine#dimensions_analyzers` methods (@janko)

* `rack_file` – Remove deprecated `Shrine::Plugins::RackFile::UploadedFile` constant (@janko)

* `rack_file` – Drop support for passing file hash to `Shrine#upload` and `Shrine#store` (@janko)

* `download_endpoint` – Move `Shrine::Plugins::DownloadEndpoint::App` into `Shrine::DownloadEndpoint` (@janko)

* `download_endpoint` – Remove deprecated `Shrine::DownloadEndpoint` constant (@janko)

* `download_endpoint` – Remove deprecated `:storages` option (@janko)

* `determine_mime_type` – Remove deprecated `:default` analyzer alias (@janko)

* `default_url` – Remove deprecated block argument when loading the plugin (@janko)

* `data_uri` – Remove deprecated `Shrine::Plugins::DataUri::DataFile` constant (@janko)

* `data_uri` – Remove deprecated `:filename` plugin option (@janko)

* `cached_attachment_data` – Remove deprecated model setter (@janko)

* `file_system` – Remove deprecated `:older_than` option in `FileSystem#clear!` (@janko)

* `file_system` – Don't accept a block anymore in `FileSystem#open` (@janko)

* `file_system` – Remove deprecated `FileSystem#download` method (@janko)

* `file_system` – Make `FileSystem#movable?` and `FileSystem#move` methods private (@janko)

* `file_system` – Remove deprecation warning on unrecognized options in `FileSystem#upload` (@janko)

* `file_system` – Remove deprecated `:host` option for `FileSystem#initialize` (@janko)

* `moving` – Remove deprecated plugin (@janko)

* `multi_delete` – Remove deprecated plugin (@janko)

* `direct_upload` – Remove deprecated plugin (@janko)

* `backup` – Remove deprecated plugin (@janko)

* `background_helpers` – Remove deprecated plugin (@janko)

* `migration_helpers` – Remove deprecated plugin (@janko)

* `copy` – Remove deprecated plugin (@janko)

* `logging` – Remove deprecated plugin (@janko)

* `s3` – Remove deprecated `S3#download` method (@janko)

* `s3` – Remove deprecated `S3#stream` method (@janko)

* `presign_endpoint` – Drop support for presign objects that don't respond to `#to_h` (@janko)

* `s3` – Return a Hash in `S3#presign` when method is POST (@janko)

* `s3` – Remove `:download` option in `S3#url` (@janko)

* `s3` – Remove support for non URI-escaped content disposition values (@janko)

* `s3` – Remove `S3#s3` method (@janko)

* `s3` – Remove support for specifying `:multipart_threshold` as an integer (@janko)

* `s3` – Remove `:host` option on `S3#initialize` (@janko)

* `s3` – Drop support for `aws-sdk-s3` versions lower than 1.14 (@janko)

* `s3` – Drop support for `aws-sdk` 2.x (@janko)

## 2.19.0 (2019-07-18) [[release notes]](https://shrinerb.com/docs/release_notes/2.19.0)

* `pretty_location` – Allow specifying a different identifier from `id` (@00dav00)

* `data_uri` – Soft-move `Shrine::Plugins::DataUri::DataFile` to `Shrine::DataFile` (@janko)

* `rack_file` – Soft-move `Shrine::Plugins::RackFile::UploadedFile` to `Shrine::RackFile` (@janko)

* `backup` – Deprecate the plugin over [mirroring uploads](https://github.com/shrinerb/shrine/wiki/Mirroring-Uploads) via the `instrumentation` plugin (@janko)

* `moving` – Deprecate the plugin in favor of the `:move` option for `FileSystem#upload` (@janko)

* `file_system` – Add `:move` option for `FileSystem#upload` (@janko)

* `file_system` – Don't fill `size` metadata if missing in `FileSystem#upload` (@janko)

* `logging` – Deprecate plugin in favour of `instrumentation` (@janko)

* `instrumentation` – Add plugin which sends events via `ActiveSupport::Notifications` or `dry-monitor` (@janko)

* `core` – Add `UploadedFile#[]` shorthand for accessing metadata (@janko)

* `add_metadata` – Allow calling `super` when overriding dynamically defined `UploadedFile` methods (@janko)

* `store_dimensions` – Add `:on_error` option for specifying the exception strategy (@janko)

* `store_dimensions` – Print warnings when exception occurred while extracting dimensions (@janko)

* `core` – Add `Shrine.logger` and make any warnings go through it (@janko)

* `copy` – Deprecate the plugin (@janko)

* `core` – Add ability to force metadata extraction by passing `metadata: true` to `Shrine#upload` (@janko)

* `core` – Add ability to skip metadata extraction by passing `metadata: false` to `Shrine#upload` (@janko)

* `file_system` – Deprecate `:older_than` option for `FileSystem#clear!` in favour of a block (@janko)

* `file_system` – Add the ability for `FileSystem#clear!` to take a block (@janko)

* `signature` – Add `Shrine.signature` alias for `Shrine.calculcate_signature` (@janko)

* `store_dimensions` – Add `Shrine.dimensions` alias for `Shrine.extract_dimensions` (@janko)

* `determine_mime_type` – Add `Shrine.mime_type` alias for `Shrine.determine_mime_type` (@janko)

* `validation_helpers` – Add `#validate_max_dimensions`, `#validate_min_dimensions`, and `#validate_dimensions` (@janko)

* `validation_helpers` - Add `#validate_size`, `#validate_width`, and `#validate_height` shorthands (@janko)

* `validation_helpers` – Add `#validate_mime_type` and `#validate_extension` aliases for inclusion (@janko)

* `validation_helpers` – Simplify default validation error messages (@janko)

* `core` – Allow registering storage objects under string keys (@janko)

## 2.18.0 (2019-06-24) [[release notes]](https://shrinerb.com/docs/release_notes/2.18.0)

* `core` – Add `Shrine.upload` method as a shorthand for `Shrine.new(...).upload(...)` (@janko)

* `upload_endpoint` – Accept file uploads from Uppy's default `files[]` array (@janko)

* `core` – Add `Shrine::Attachment()` shorthand for `Shrine::Attachment.new` (@janko)

* `upload_endpoint` – Add `:url` option for adding uploaded file URL to response body (@janko)

* `s3` – Deprecate `:download` URL option over `:response_content_disposition` (@janko)

* `s3` – Remove backfilling `size` metadata when uploading IO objects of unknown size (@janko)

* `s3` – Deprecate `aws-sdk-s3` version less than 1.14.0 (@janko)

* `presign_endpoint` – Add `Shrine.presign_response` for handling presigns inside a custom controller (@janko)

* `upload_endpoint` – Add `Shrine.upload_response` for handling uploads inside a custom controller (@janko)

* `rack_file` – Fix overriden `Attacher#assign` not accepting second argument (@janko)

* `parsed_json` – Fix overriden `Attacher#assign` not accepting second argument (@janko)

## 2.17.0 (2019-05-06) [[release notes]](https://shrinerb.com/docs/release_notes/2.17.0)

* `data_uri` – Add `Attacher#assign_data_uri` which accepts additional `Shrine#upload` options (@janko)

* `remote_url` – Accept additional `Shrine#upload` options in `Attacher#assign_remote_url` (@janko)

* `download_endpoint` – Allow passing options to `Shrine.download_endpoint` (@janko)

* `download_endpoint` – Fix `Shrine.download_endpoint` not being accepted by Rails' `#mount` (@janko)

* `download_endpoint` – Remove Roda dependency (@janko)

* `presign_endpoint` – Soft-rename `Shrine::Plugins::PresignEndpoint::App` class to `Shrine::PresignEndpoint` (@janko)

* `upload_endpoint` – Soft-rename `Shrine::Plugins::UploadEndpoint::App` class to `Shrine::UploadEndpoint` (@janko)

* `processing` – Fix defining process blocks being applied to `Shrine` superclasses (@ksol)

* `derivation_endpoint` – Add `ETag` header to prevent `Rack::ETag` from buffering file content (@janko)

* `rack_response` – Add `ETag` header to prevent `Rack::ETag` from buffering file content (@janko)

* `download_endpoint` – Add `ETag` header to prevent `Rack::ETag` from buffering file content (@janko)

* `default_url` – Add `:host` for specifying the URL host (@janko)

* `versions` – Fix uploaded versions being deleted when string version names are used (@janko)

* `versions` – Allow `Attacher#url` to accept version name indifferently (@FunkyloverOne)

* Improve performance of cleaning empty directories on deletion in `FileSystem` storage (@adamniedzielski)

* Drop MRI 2.3 support (@janko)

* `metadata_attributes` – Fix `Attacher#assign` not accepting additional options anymore (@janko)

* `derivation_endpoint` – Add support for Rack < 2 (@Antsiscool)

* `derivation_endpoint` – Fix `:upload` option being incompatible with `moving` plugin (@speedo-spin)

* `determine_mime_type` – Allow passing options to analzyers (Marcel accepts `:filename_fallback` option) (@hmistry)

* `determine_mime_type` – Revert "Extended determine MIME type with Marcel" (@hmistry)

* `rack_response` – improve performance for upper bounded `Range` header values (@zarqman)

* `rack_response` – prevent response body from yielding `nil`-chunks (@zarqman)

* `parsed_json` – Accepts hashes with symbols keys (@aglushkov)

## 2.16.0 (2019-02-18) [[release notes]](https://shrinerb.com/docs/release_notes/2.16.0)

* `derivation_endpoint` – Add `:upload_open_options` for download option for derivation result (@janko)

* `derivation_endpoint` – Fix `:upload` option being incompatible with `delete_raw` plugin (@janko)

* `derivation_endpoint` – Require input file in `Derivation#upload` to respond to `#path` (@janko)

* `derivation_endpoint` – Delete generated derivation result after uploading in `Derivation#upload` (@janko)

* `derivation_endpoint` – Fix `Derivation#processed` breaking when derivation result is a `File` object (@janko)

* `derivation_endpoint` – Don't close input file on `Derivation#upload` (@janko)

* Add `:delete` parameter for skipping delete when `delete_raw` plugin is loaded (@janko)

* Don't return `Content-Type` when it couldn't be determined from file extension in `derivation_endpoint` (@janko)

* Add `:download_options` option to `download_endpoint` plugin for specifying options for `Storage#open` (@janko)

* Don't return `Content-Type` header in `rack_response` when MIME type could not be determined (@janko)

* Open the `UploadedFile` object in `#to_rack_response` in `rack_response` plugin (@janko)

* Fix `store_dimensions` plugin making second argument in `Shrine#extract_metadata` mandatory (@jrochkind)

## 2.15.0 (2019-02-08) [[release notes]](https://shrinerb.com/docs/release_notes/2.15.0)

* Add `derivation_endpoint` plugin for processing uploaded files on-the-fly (@janko)

* Allow Marcel to fall back to the file extension in `determine_mime_type` plugin (@skarlcf)

* Don't return cached app instance in `Shrine.download_endpoint` in `download_endpoint` plugin (@janko)

* Yield a new File object on `Shrine.with_file` when `tempfile` plugin is loaded (@janko)

## 2.14.0 (2018-12-27) [[release notes]](https://shrinerb.com/docs/release_notes/2.14.0)

* Add `tempfile` plugin for easier reusing of the same uploaded file copy on disk (@janko)

* Don't re-open the uploaded file if it's already open in `refresh_metadata` plugin (@janko)

* Drop support for MRI 2.1 and 2.2 (@janko)

* Fix `backgrounding` not working when default storage was changed with `Attachment.new` (@janko)

* Don't clear existing metadata definitions when loading `add_metadata` plugin (@janko)

* Don't clear existing processing blocks when loading `processing` plugin (@janko)

* Deprecate automatic escaping of `:content_disposition` in `Shrine::Storage::S3` (@janko)

* Use `content_disposition` gem in `Shrine::Storage::S3` and `rack_response` plugin (@janko)

* Make `FileSystem#clear!` work correctly when the storage directory is a symlink (@janko)

* Don't abort promotion in `backgrounding` plugin when original metadata was updated (@janko)

* Don't mutate the `UploadedFile` data hash in `refresh_metadata` plugin (@janko)

* Deprecate `Storage::S3#download` (@janko)

* Stop using `Storage#download` in `UploadedFile#download` for peformance (@janko)

* Remove `#download` from the Shrine storage specification (@janko)

* Keep `context` argument in `#extract_metadata` optional after loading `add_metadata` plugin (@janko)

* Include metadata key with `nil` value when `nil` is returned in `add_metadata` block (@janko)

* Strip query params in upload location when re-uploading from `shrine-url` storage (@jrochkind)

* Inline Base plugin into core classes, extract them to separate files (@printercu)

* Make `rack_response` plugin work with `Rack::Sendfile` for `FileSystem` storage (@janko)

* Add `:filename` and `:type` options to `rack_response` plugin (@janko)

* Add `:host` option to `UploadedFile#download_url` in `download_endpoint` plugin (@janko)

* Add support for client-side encryption to S3 storage (@janko)

* Don't look up the attachment class in each new model instance (@printercu)

* Allow `Attacher#cached?` and `Attacher#stored?` to take an `UploadedFile` object (@jrochkind)

* Allow assigning a filename to the `DataFile` object in `Shrine.data_uri` (@janko)

* Don't strip media type parameters for the `DataFile` object in `data_uri` plugin (@janko)

* Add `:content_type` analyzer to `Shrine.mime_type_analyzers` in `determine_mime_type` plugin (@janko)

* Rename `:default` analyzer to `:content_type` in `determine_mime_type` plugin (@janko)

* Don't display a warning when `determine_mime_type` plugin is loaded with `:default` analyzer (@janko)

* Exclude media type parameters when copying `IO#content_type` into `mime_type` metadata (@janko)

* Remove superfluous `#head_object` S3 API call in `S3#download` (@janko)

* Make `S3#download` and `S3#open` work with server side encryption options (@janko)

* Make previously extracted metadata available under `:metadata` in `add_metadata` plugin (@jrochkind)

* Use a guard raise cause for `bucket` argument in S3 for an appropriate error message (@ardecvz)

## 2.13.0 (2018-11-04) [[release notes]](https://shrinerb.com/docs/release_notes/2.13.0)

* Specify UTF-8 charset in `Content-Type` response header in `presign_endpoint` plugin (@janko)

* Specify UTF-8 charset in `Content-Type` response header in `upload_endpoint` plugin (@janko)

* Force UTF-8 encoding on filenames coming from Rack's multipart request params in `rack_file` plugin (@janko)

* Raise `Shrine::Error` if `file` command returns error in stdout in `determine_mime_type` plugin (@janko)

* Allow `:host` in `S3#url` to specify a host URL with an additional path prefix (@janko)

* Revert adding bucket name to URL path in `S3#url` when `:host` is used with `:force_path_style` (@janko)

* In `upload_endpoint` error with "Upload Not Valid" when `file` parameter is present but not a file (@janko)

* Allow `Attacher#assign` to accept options for `Shrine#upload` (@janko)

* Add `:metadata` option to `Shrine#upload` for manually overriding extracted metadata (@janko)

* Add `:force` option to `infer_extension` plugin for always replacing the current extension (@jrochkind)

* Add `:public` option to `S3#initialize` for enabling public uploads (@janko)

* Add ability to specify a custom `:signer` for `Shrine::Storage::S3#url` (@janko)

* In `S3#upload` do multipart upload for large non-file IO objects (@janko)

* In `S3#upload` switch to `Aws::S3::Object#upload_stream` for multipart uploads of IO objects of unknown size (@janko)

* In `S3#upload` deprecate using aws-sdk-s3 lower than 1.14 when uploading IO objects of unknown size (@janko)

## 2.12.0 (2018-08-22) [[release notes]](https://shrinerb.com/docs/release_notes/2.12.0)

* Ignore nil values when assigning files from a remote URL (@janko)

* Ignore nil values when assigning files from a data URI (@GeekOnCoffee)

* Raise `Shrine::Error` when child process failed to be spawned in `:file` MIME type analyzer (@hmistry)

* Use the appropriate unit in error messages of filesize validators in `validation_helpers` plugin (@hmistry)

* Fix subclassing not inheriting storage resolvers from superclass in `dynamic_storage` plugin (@janko)

* Un-deprecate assigning cached versions (@janko)

* Add `Attacher#assign_remote_url` which allows dynamically passing downloader options (@janko)

* Deprecate `:storages` option in `download_endpoint` plugin in favour of `UploadedFile#download_url` (@janko)

* Add `:redirect` option to `download_endpoint` plugin for redirecting to the uploaded file (@janko)

* Fix encoding issues when uploading IO object with unknown size to S3 (@janko)

* Accept additional `File.open` arguments in `FileSystem#open` (@janko)

* Add `:rewindable` option to `S3#open` for disabling caching of read content to disk (@janko)

* Make `UploadedFile#open` always open a new IO object and close the previous one (@janko)

## 2.11.0 (2018-04-28) [[release notes]](https://shrinerb.com/docs/release_notes/2.11.0)

* Add `Shrine.with_file` for temporarily converting an IO-like object into a file (@janko)

* Add `:method` value to the `S3#presign` result indicating the HTTP verb that should be used (@janko)

* Add ability to specify `method: :put` in `S3#presign` to generate data for PUT upload (@janko)

* Return a `Struct` instead of a `Aws::S3::PresignedPost` object in `S3#presign` (@janko)

* Deprecate `Storage#presign` returning a custom object in `presign_endpoint` (@janko)

* Allow `Storage#presign` to return a Hash in `presign_endpoint` (@janko)

* Add ability to specify upload checksum in `upload_endpoint` plugin (@janko)

* Don't raise exception in `:mini_magick` and `:ruby_vips` dimensions analyzers when image is invalid (@janko)

* Don't remove bucket name from S3 URL path with `:host` when `:force_path_style` is set (@janko)

* Correctly determine MIME type from extension of empty files (@janko)

* Modify `UploadedFile#download` not to reopen the uploaded file if it's already open (@janko)

* Add `UploadedFile#stream` for streaming content into a writable object (@janko)

* Deprecate `direct_upload` plugin in favor of `upload_endpoint` and `presign_endpoint` plugins (@janko)

## 2.10.0 (2018-03-28) [[release notes]](https://shrinerb.com/docs/release_notes/2.10.0)

* Add `:fastimage` analyzer to `determine_mime_type` plugin (@mokolabs)

* Keep download endpoint URL the same regardless of metadata ordering (@MSchmidt)

* Remove `:rack_mime` extension inferrer from the `infer_extension` plugin (@janko)

* Allow `UploadedFile#download` to accept a block for temporary file download (@janko)

* Add `:ruby_vips` analyzer to `store_dimensions` plugin (@janko)

* Add `:mini_magick` analyzer to `store_dimensions` plugin (@janko)

* Soft-rename `:heroku` logging format to `:logfmt` (@janko)

* Deprecate `Shrine::IO_METHODS` constant (@janko)

* Don't require IO size to be known on upload (@janko)

* Inherit the logger on subclassing `Shrine` and make it shared across subclasses (@hmistry)

## 2.9.0 (2018-01-27) [[release notes]](https://shrinerb.com/docs/release_notes/2.9.0)

* Support arrays of files in `versions` plugin (@janko)

* Added `:marcel` analyzer to `determine_mime_type` plugin (@janko)

* Deprecate `:filename` option of the `data_uri` plugin in favour of the new `infer_extension` plugin (@janko)

* Add `infer_extension` plugin for automatically deducing upload location extension from MIME type (@janko)

* Apply default storage options passed via `Attachment.new` in `backgrounding` plugin (@janko)

* Fix S3 storage replacing spaces in filename with "+" symbols (@ndbroadbent)

* Deprecate the `multi_delete` plugin (@janko)

* Allow calling `UploadedFile#open` without passing a block (@hmistry)

* Delete tempfiles in case of errors in `UploadedFile#download` and `Storage::S3#download` (@hmistry)

* Freeze all string literals (@hmistry)

* Allow passing options to `Model#<attachment>_attacher` for overriding `Attacher` options (@janko)

## 2.8.0 (2017-10-11) [[release notes]](https://shrinerb.com/docs/release_notes/2.8.0)

* Expand relative directory paths when initializing `Storage::FileSystem` (@janko)

* Fix `logging` plugin erroring on `:json` format when ActiveSupport is loaded (@janko)

* Allow `Storage::S3#clear!` to take a block for specifying which objects to delete (@janko)

* Make `:filemagic` analyzer close the FileMagic descriptor even in case of exceptions (@janko)

* Make `:file` analyzer work for potential file types which have magic bytes farther than 256 KB (@janko)

* Deprecate `aws-sdk` 2.x in favour of the new `aws-sdk-s3` gem (@janko)

* Modify `UploadedFile#extension` to always return the extension in lowercase format (@janko)

* Downcase the original file extension when generating an upload location (@janko)

* Allow specifying the full record attribute name in `metadata_attributes` plugin (@janko)

* Allow specifying metadata mappings on `metadata_attributes` plugin initialization (@janko)

* Add support for ranged requests in `download_endpoint` and `rack_response` plugins (@janko)

* Allow `Storage::S3#open` and `Storage::S3#download` to accept additional options (@janko)

* Forward any options given to `UploadedFile#open` or `UploadedFile#download` to the storage (@janko)

* Update `direct_upload` plugin to support Roda 3 (@janko)

## 2.7.0 (2017-09-11) [[release notes]](https://shrinerb.com/docs/release_notes/2.7.0)

* Deprecate the `Shrine::DownloadEndpoint` constant over `Shrine.download_endpoint` (@janko)

* Allow an additional `#headers` attribute on presigns and return it in `presign_endpoint` (@janko)

* Allow overriding `upload_endpoint` and `presign_endpoint` options per-endpoint (@janko)

* Add `:presign` and `:rack_response` options to `presign_endpoint` (@janko)

* Add `:upload`, `:upload_context` and `:rack_response` options to `upload_endpoint` (@janko)

* Modify `upload_endpoint` and `presign_endpoint` to return `text/plain` error responses (@janko)

* Add `:request` upload context parameter in `upload_endpoint` (@janko)

* Change `:action` upload context parameter to `:upload` in `upload_endpoint` (@janko)

* Return `405 Method Not Allowed` on invalid HTTP verb in `upload_endpoint` and `presign_endpoint` (@janko)

* Modify `upload_endpoint` and `presign_endpoint` to handle requests on the root URL (@janko)

* Allow creating Rack apps dynamically in `upload_endpoint` and `presign_endpoint` (@janko)

* Remove Roda dependency from `upload_endpoint` and `presign_endpoint` plugins (@janko)

* Split `direct_upload` plugin into `upload_endpoint` and `presign_endpoint` plugins (@janko)

* Support the new `aws-sdk-s3` gem in `Shrine::Storage::S3` (@lizdeika)

* Return `Cache-Control` header in `download_endpoint` to permanently cache responses (@janko)

* Return `404 Not Found` when uploaded file doesn't exist in `download_endpoint` (@janko)

* Utilize uploaded file metadata when generating response in `download_endpoint` (@janko)

* Fix deprecation warning when generating fake presign with query parameters (@janko)

* Don't raise error in `file` and `filemagic` MIME type analyzer on empty IO (@ypresto)

* Require `down` in `remote_url` plugin even when a custom downloader is given (@janko)

* Require `time` library in `logging` plugin to fix `undefined method #iso8601 for Time` (@janko)

* Allow validations defined on a superclass to be reused in a subclass (@printercu)

* Allow validation error messages to be an array of arguments for ActiveRecord (@janko)

* Allow model subclasses to override the attachment with a different uploader (@janko)

* Accept `Attacher.new` options like `store:` and `cache:` via `Attachment.new` (@ypresto)

* Raise `ArgumentError` when `:bucket` option is nil in `Shrine::Storage::S3#initialize` (@janko)

* Don't wrap base64-encoded content into 60 columns in `UploadedFile#base64` and `#data_uri` (@janko)

* Add `:mini_mime` option to `determine_mime_type` plugin for using the [mini_mime](https://github.com/discourse/mini_mime) gem (@janko)

* Fix `data_uri` plugin raising an exception on Ruby 2.4.1 when using raw data URIs (@janko)

* Implement `Shrine::Storage::S3#open` using the aws-sdk gem instead of `Down.open` (@janko)

* Un-deprecate `Shrine.uploaded_file` accepting file data as JSON string (@janko)

* Don't wrap base64-formatted signatures to 60 columns (@janko)

* Don't add a newline at the end of the base64-formatted signature (@janko)

## 2.6.1 (2017-04-12) [[release notes]](https://shrinerb.com/docs/release_notes/2.6.1)

* Fix `download_endpoint` returning incorrect reponse body in some cases (@janko)

## 2.6.0 (2017-04-04) [[release notes]](https://shrinerb.com/docs/release_notes/2.6.0)

* Make `Shrine::Storage::FileSystem#path` public which returns path to the file as a `Pathname` object (@janko)

* Add `Shrine.rack_file` to `rack_file` plugin for converting Rack uploaded file hash into an IO (@janko)

* Deprecate passing a Rack file hash to `Shrine#upload` (@janko)

* Expose `Shrine.extract_dimensions` and `Shrine.dimensions_analyzers` in `store_dimensions` plugin (@janko)

* Add `metadata_attributes` plugin for syncing attachment metadata with additional record attributes (@janko)

* Remove the undocumented `:magic_header` option from `determine_mime_type` plugin (@janko)

* Expose `Shrine.determine_mime_type` and `Shrine.mime_type_analyzers` in `determine_mime_type` plugin (@janko)

* Add `signature` plugin for calculating a SHA{1,256,384,512}/MD5/CRC32 hash of a file (@janko)

* Return the resolved plugin module when calling `Shrine.plugin` (@janko)

* Accept hash of metadata with symbol keys as well in `add_metadata` block (@janko)

* Add `refresh_metadata` plugin for re-extracting metadata from an uploaded file (@janko)

* Allow S3 storage to use parallelized multipart upload for files from FileSystem storage as well (@janko)

* Improve default multipart copy threshold for S3 storage (@janko)

* Allow specifying multipart upload and copy thresholds separately in `Shrine::Storage::S3` (@janko)

* Fix `Storage::FileSystem#clear!` not deleting old files if there are newer files in the same directory (@janko)

* Allow media type in the data URI to have additional parameters (@janko)

* URI-decode non-base64 data URIs, as such data URIs are URI-encoded according to the specification (@janko)

* Improve performance of parsing data URIs by 10x switching from a regex to StringScanner (@janko)

* Reduce memory usage of `Shrine.data_uri` and `UploadedFile#base64` by at least 2x (@janko)

* Add `Shrine.data_uri` to `data_uri` plugin which parses and converts the given data URI to an IO object (@janko)

* Make `rack_file` plugin work with HashWithIndifferentAccess-like objects such as Hashie::Mash (@janko)

* Expose `Aws::S3::Client` via `Shrine::Storage::S3#client`, and deprecate `Shrine::Strorage::S3#s3` (@janko)

* Modify `delete_raw` plugin to delete any IOs that respond to `#path` (@janko)

* Require the Tempfile standard library in lib/shrine.rb (@janko)

* Deprecate dimensions validations passing when a dimension is nil (@janko)

* Deprecate passing regexes to type/extension whitelists/blacklists in `validation_helpers` (@janko)

* Don't include list of blacklisted types and extensions in default `validation_helpers` messages (@janko)

* Improve default error messages in `validation_helpers` plugin (@janko)

* Don't require the `benchmark` standard library in `logging` plugin (@janko)

* Don't dirty the attacher in `Attacher#set` when attachment hasn't changed (@janko)

* Rename `Attacher#attached?` to a more accurate `Attacher#changed?` (@janko)

* Allow calling `Attacher#finalize` if attachment hasn't changed, instead of raising an error (@janko)

* Make `Shrine::Storage::S3#object` method public (@janko)

* Prevent autoloading race conditions in aws-sdk gem by eager loading the S3 service (@janko)

* Raise `Shrine::Error` when `Shrine#generate_location` returns nil (@janko)

## 2.5.0 (2016-11-11) [[release notes]](https://shrinerb.com/docs/release_notes/2.5.0)

* Add `Attacher.default_url` as the idiomatic way of declaring default URLs (@janko)

* Allow uploaders themselves to accept Rack uploaded files when `rack_file` is loaded (@janko)

* Raise a descriptive error when two versions are pointing to the same IO object (@janko)

* Make `backgrounding` plugin work with plain model instances (@janko)

* Make validation methods in `validation_helpers` plugin return whether validation succeeded (@janko)

* Make extension matching case insensitive in `validation_helpers` plugin (@jonasheinrich)

* Make `remove_invalid` plugin remove dirty state on attacher after removing invalid file (@janko)

* Raise error if `Shrine::UploadedFile` isn't initialized with valid data (@janko)

* Accept `extension` parameter without the dot in presign endpoint of `direct_upload` plugin (@jonasheinrich)

* Add `:fallback_to_original` option to `versions` plugin for disabling fallback to original file (@janko)

* Add `#dimensions` method to `UploadedFile` when loading `store_dimensions` plugin (@janko)

* Make it possible to extract multiple metadata values at once with the `add_metadata` plugin (@janko)

## 2.4.1 (2016-10-17) [[release notes]](https://shrinerb.com/docs/release_notes/2.4.1)

* Move back JSON serialization from `Attacher#write` to `Attacher#_set` (@janko)

* Make `remove_invalid` plugin assign back a previous attachment if was there (@janko)

* Deprecate `Storage::FileSystem#download` (@janko)

* In `UploadedFile#download` use extension from `#original_filename` if `#id` doesn't have it (@janko)

## 2.4.0 (2016-10-11) [[release notes]](https://shrinerb.com/docs/release_notes/2.4.0)

* Add `#convert_before_write` and `#convert_after_read` on the Attacher for data attribute conversion (@janko)

* Extract the `<attachment>_data` attribute name into `Attacher#data_attribute` (@janko)

* Support JSON and JSONB PostgreSQL columns with ActiveRecord (@janko)

* Fix S3 storage not handling filenames with double quotes in Content-Disposition header (@janko)

* Work around aws-sdk failing with non-ASCII characters in Content-Disposition header (@janko)

* Allow dynamically generating URL options in `default_url_options` plugin (@janko)

* Don't run file validations when duplicating the record in `copy` plugin (@janko)

* Don't use `Storage#stream` in download_endpoint plugin anymore, rely on `Storage#open` (@janko)

* Remove explicitly unlinking Tempfiles returned by `Storage#open` (@janko)

* Move `:host` from first-class storage option to `#url` option on FileSystem and S3 storage (@janko)

* Don't fail in FileSystem storage when attempting to delete a file that doesn't exist (@janko)

* In `UploadedFile#open` handle the case when `Storage#open` raises an error (@janko)

* Make the `sequel` plugin use less memory during transactions (@janko)

* Use Roda's streaming plugin in `download_endpoint` for better EventMachine integration (@janko)

* Deprecate accepting a JSON string in `Shrine.uploaded_file` (@janko)

* In S3 storage automatically write original filename to `Content-Disposition` header (@janko)

* Override `#to_s` in `Shrine::Attachment` for better introspection with `puts` (@janko)

## 2.3.1 (2016-09-01) [[release notes]](https://shrinerb.com/docs/release_notes/2.3.1)

* Don't change permissions of existing directories in FileSystem storage (@janko)

## 2.3.0 (2016-08-27) [[release notes]](https://shrinerb.com/docs/release_notes/2.3.0)

* Prevent client from caching the presign response in direct_upload plugin (@janko)

* Make Sequel update only the attachment in background job (@janko)

* Add copy plugin for copying files from one record to another (@janko)

* Disable moving when uploading stored file to backup storage (@janko)

* Make `Attacher#recache` from the recache plugin public for standalone usage (@janko)

* Allow changing `Shrine::Attacher#context` once the attacher is instantiated (@janko)

* Make `Attacher#read` for reading the attachment column public (@janko)

* Don't rely on the `#id` writer on a model instance in backgrounding plugin (@janko)

* Don't make `Attacher#swap` private in sequel and activerecord plugins (@janko)

* Set default UNIX permissions to 0644 for files and 0755 for directories (@janko)

* Apply directory permissions to all subfolders inside the main folder (@janko)

* Add `:directory_permissions` to `Storage::FileSystem` (@janko)

## 2.2.0 (2016-07-29) [[release notes]](https://shrinerb.com/docs/release_notes/2.2.0)

* Soft deprecate `:phase` over `:action` in `context` (@janko)

* Add ability to sequel and activerecord plugins to disable callbacks and validations (@janko)

* The direct_upload endpoint now always includes both upload and presign routes (@janko)

* Don't let the combination for delete_raw and moving plugins trigger any errors (@janko)

* Add `UploadedFile#open` that mimics `File.open` with a block (@janko)

* In the storage linter don't require `#clear!` to be implemented (@janko)

* In backgrounding plugin don't require model to have attachment module included (@janko)

* Add add_metadata plugin for defining additional metadata values to be extracted (@janko)

* In determine_mime_type plugin raise error when file command wasn't found or errored (@janko)

* Add processing plugin for simpler and more declarative definition of processing (@janko)

* Storage classes don't need to implement the `#read` method anymore (@janko)

* Use aws-sdk in `S3#download`, which will automatically retry failed downloads (@janko)

* Add `:multipart_threshold` for when S3 storage should use parallelized multipart copy/upload (@janko)

* Automatically use optimized multipart S3 upload for files larger than 15MB (@janko)

* Avoid an additional HEAD request to determine content length in multipart S3 copy (@janko)

## 2.1.1 (2016-07-14) [[release notes]](https://shrinerb.com/docs/release_notes/2.1.1)

* Fix `S3#open` throwing a NameError if `net/http` isn't required (@janko)

## 2.1.0 (2016-06-27) [[release notes]](https://shrinerb.com/docs/release_notes/2.1.0)

* Remove `:names` from versions plugin, and deprecate generating versions in :cache phase (@janko)

* Pass a `Shrine::UploadedFile` in restore_cached_data instead of the raw IO (@janko)

* Increase magic header length in determine_mime_type and make it configurable (@janko)

* Execute `file` command in determine_mime_type the same way for files as for general IOs (@janko)

* Make logging and parallelize plugins work properly when loaded in this order (@janko)

* Don't assert arity of IO methods, so that objects like `Rack::Test::UploadedFile` are allowed (@janko)

* Deprecate `#cached_<attachment>_data=` over using `<attachment>` for the hidden field (@janko)

## 2.0.1 (2016-05-30) [[release notes]](https://shrinerb.com/docs/release_notes/2.0.1)

* Don't override previously set default_url in versions plugin (@janko)

## 2.0.0 (2016-05-19) [[release notes]](https://shrinerb.com/docs/release_notes/2.0.0)

* Include query parameters in CDN-ed S3 URLs, making them work for private objects (@janko)

* Remove the `:include_error` option from remote_url plugin (@janko)

* Make previous plugin options persist when reapplying the plugin (@janko)

* Improve how upload options and metadata are passed to storage's `#upload` and `#move` (@janko)

* Remove `Shrine::Confirm` and confirming `Storage#clear!` in general (@janko)

* Allow implementing a custom dimensions analyzer using built-in ones (@janko)

* Don't error in determine_mime_type when MimeMagic cannot determine the MIME (@janko)

* Allow implementing a custom MIME type analyzer using built-in ones (@janko)

* Don't check that the cached file exists in restore_cached_data plugin (@janko)

* Deprecate migration_helpers plugin and move `Attacher#cached?` and `Attacher#stored?` to base (@janko)

* Don't trigger restore_cached_data plugin functionality when assigning the same cached attachment (@janko)

* Give `Attacher#_promote` and `Attacher#promote` the same method signature (@janko)

* Add `Attacher#_delete` which now spawns a background job instead of `Attacher#delete!` (@janko)

* Make `Attacher#cache!`, `Attacher#store!`, and `Attacher#delete!` public (@janko)

* Don't cache storages in dynamic_storage plugin (@janko)

* Make only one HTTP request in download_endpoint plugin (@janko)

* Print secuity warning when not using determine_mime_type plugin (@janko)

* Support Mongoid in backgrounding plugin (@janko)

* Allow including attachment module to non-`Sequel::Model` objects in sequel plugin (@janko)

* Handle paths that start with "-" in determine_mime_type plugin when `:file` analyzer is used (@zaeleus)

* Allow including attachment module to non-`ActiveRecord::Base` objects in activerecord plugin (@janko)

* Remove deprecated "restore_cached" alias for restore_cached_data plugin (@janko)

* Remove deprecated "delete_uploaded" alias for delete_raw plugin (@janko)

* Make the default generated unique location shorter (@janko)

* Make the `:delegate` option in migration_helpers default to `false` (@janko)

* Don't require `:storages` option anymore in moving plugin (@janko)

* Don't delete uploaded IO if storage doesn't support moving in moving plugin (@janko)

* Rename delete phases to be shorter and consistent in naming with upload phases (@janko)

* Remove deprecated `Shrine#default_url` (@janko)

* Remove deprecated `:subdirectory` on FileSystem storage (@janko)

* Don't return the uploaded file in `Attacher#set` and `Attacher#assign` (@janko)

* Return the attacher instance in `Attacher.promote` and `Attacher.delete` in backgrounding plugin (@janko)

* Rename "attachment" to "name", and "uploaded_file" to "attachment" in backgrounding plugin (@janko)

* Remove using `:presign` for presign options instead of `:presign_options` (@janko)

* Remove deprecated `Shrine.direct_endpoint` from direct_upload plugin (@janko)

* Remove deprecated keep_location plugin (@janko)

* Make `Shrine#extract_dimensions` a private method in store_dimensions plugin (@janko)

* Keep `Shrine#extract_mime_type` a private method when loading determine_mime_type plugin (@janko)

* Deprecate loading the backgrounding plugin through the old "background_helpers" alias (@janko)

## 1.4.2 (2016-04-19) [[release notes]](https://shrinerb.com/docs/release_notes/1.4.2)

* Removed ActiveRecord's automatic support for optimistic locking as it wasn't stable (@janko)

* Fixed record's dataset being modified after promoting preventing further updates with the same instance (@janko)

## 1.4.1 (2016-04-18) [[release notes]](https://shrinerb.com/docs/release_notes/1.4.1)

* Bring back triggering callbacks on promote in ORM plugins, and add support for optimistic locking (@janko)

## 1.4.0 (2016-04-15) [[release notes]](https://shrinerb.com/docs/release_notes/1.4.0)

* Return "Content-Length" response header in download_endpoint plugin (@janko)

* Make determine_mime_type and store_dimensions automatically rewind IO with custom analyzer (@janko)

* Make `before_*` and `after_*` hooks happen before and after `around_*` hooks (@janko)

* Rename restore_cached plugin to more accurate "restore_cached_data" (@janko)

* Prevent errors when attempting to validate dimensions when they are absent (@janko)

* Remove "thread" gem dependency in parallelize plugin (@janko)

* Add `:filename` to data_uri plugin for generating filenames based on content type (@janko)

* Make user-defined hooks always happen around logging (@janko)

* Add `:presign_location` to direct_upload for generating the key (@janko)

* Add separate `:presign_options` option for receiving presign options in direct_upload plugin (@janko)

* Add ability to generate fake presigns for storages which don't support them for testing (@janko)

* Change the `/:storage/:name` route to `/:storage/upload` in direct_upload plugin (@janko)

* Fix logger not being inherited in the logging plugin (@janko)

* Add delete_promoted plugin for deleting promoted files after record has been updated (@janko)

* Allow passing phase to `Attacher#promote` and generalize promoting background job (@janko)

* Close the cached file after extracting its metadata in restore_cached plugin (@janko)

* Rename delete_uploaded plugin to "delete_raw" to better explain its functionality (@janko)

* Pass the SSL CA bundle to open-uri when downloading an S3 file (@janko)

* Add `Attacher.dump` and `Attacher.load` for writing custom background jobs with custom functionality (@janko)

* Fix S3 URL erroring due to not being URL-encoded when `:host` option is used (@janko)

* Remove a tiny possibility of a race condition with backgrounding on subsequent updates (@janko)

* Add `:delegate` option to migration_helpers for opting out of defining methods on the model (@janko)

* Make logging plugin log number of both input and output files for processing (@janko)

* Make deleting backup work with backgrounding plugin (@janko)

* Make storing backup happen *after* promoting instead of before (@janko)

* Add `:fallbacks` to versions plugin for fallback URLs for versions which haven't finished processing (@janko)

* Fix keep_files not to spawn a background job when file will not be deleted (@janko)

## 1.3.0 (2016-03-12) [[release notes]](https://shrinerb.com/docs/release_notes/1.3.0)

* Add `<attachment>_cached?` and `<attachment>_stored?` to migration_helpers plugin (@janko)

* Fix `Attacher#backup_file` from backup plugin not to modify the given uploaded file (@janko)

* Allow modifying UploadedFile's data hash after it's instantiated to change the UploadedFile (@janko)

* Deprecate the keep_location plugin (@janko)

* Don't mutate context hash inside the uploader (@janko)

* Make extracted metadata accessible in `#generate_location` through `:metadata` in context hash (@janko)

* Don't require the "metadata" key when instantiating a `Shrine::UploadedFile` (@janko)

* Add `:include_error` option to remote_url for accessing download error in `:error_message` block (@janko)

* Give different error message when file wasn't found or was too large in remote_url (@janko)

* Rewind the IO after extracting MIME type with MimeMagic (@janko)

* Rewind the IO after extracting image dimensions even when extraction failed (@kaapa)

* Correctly infer the extension in `#generate_location` when uploading an `UploadedFile` (@janko)

* Fix ability for errors to accumulate in data_uri and remote_url plugins when assigning mutliples to same record instance (@janko)

* Bump Down dependency to 2.0.0 in order to fix downloading URLs with "[]" characters (@janko)

* Add `:namespace` option to pretty_location for including class namespace in location (@janko)

* Don't include the namespace of the class in the location with the pretty_location plugin (@janko)

* Remove aws-sdk deprecation warning when storage isn't instantiated with credentials (@reidab)

* Don't make uploaded file's metadata methods error when the corresponding key-value pair is missing (@janko)

* Close the `UploadedFile` on upload only if it was previously opened, which doesn't happen on S3 COPY (@reidab)

* Fix `NameError` when silencing "missing record" errors in backgrounding (@janko)

## 1.2.0 (2016-01-26) [[release notes]](https://shrinerb.com/docs/release_notes/1.2.0)

* Make `Shrine::Attacher.promote` and `Shrine::Attacher.delete` return the record in backgrounding plugin (@janko)

* Close the IO on upload even if the upload errors (@janko)

* Use a transaction when checking if attachment has changed after storing during promotion (@janko)

* Don't attempt to start promoting in background if attachment has already changed (@janko)

* Don't error in backgrounding when record is missing (@janko)

* Prevent multiline content type spoof attempts in validation_helpers (@xzo)

* Make custom metadata inherited from uploaded files and make `#extract_metadata` called only on caching (@janko)

## 1.1.0 (2015-12-26) [[release notes]](https://shrinerb.com/docs/release_notes/1.1.0)

* Rename the "background_helpers" plugin to "backgrounding" (@janko)

* Rename the `:subdirectory` option to `:prefix` on FileSystem storage (@janko)

* Add download_endpoint plugin for downloading files uploaded to database storages and for securing downloads (@janko)

* Make `around_*` hooks return the result of the corresponding action (@janko)

* Make the direct upload endpoint customizable, inheritable and inspectable (@janko)

* Add upload_options plugin for dynamically generating storage-specific upload options (@janko)

* Allow the context hash to be modified (@janko)

* Fix extension not being returned for storages which remove it from ID (Flickr, SQL, GridFS) (@janko)

* Delete underlying Tempfiles when closing an `UploadedFile` (@janko)

* Fix background_helpers plugin not working with ActiveJob (@janko)

* Add `UploadedFile#base64` to the data_uri plugin (@janko)

* Optimize `UploadedData#data_uri` to not download the file and instantiate file contents string only once (@janko)

* Allow adding S3 upload options dynamically per upload (@janko)

* Add delete_uploaded plugin for automatically deleting files after they're uploaded (@janko)

* Close an open file descriptor left after downloading a FileSystem file (@janko)

* Make `FileSystem#url` Windows compatible (@janko)

* Add `UploadedFile#content_type` alias to `#mime_type` for better integration with upload libraries (@janko)

* Add a `UploadedFile#data_uri` method to the data_uri plugin (@janko)

* Allow the data_uri plugin to accept "+" symbols in MIME type names (@janko)

* Make the data_uri plugin accept data URIs which aren't base64 encoded (@janko)

* Close all IOs after uploading them (@janko)

* Allow passing a custom IO object to the Linter (@janko)

* Add remove_invalid plugin for automatically deleting and deassigning invalid cached files (@janko)

* Add `:max_size` option to the direct_upload plugin (@janko)

* Move `Shrine#default_url` to default_url plugin (@janko)

* Enable `S3#multi_delete` to delete more than 1000 objects by batching deletes (@janko)

* Add the keep_location plugin for easier debugging or backups (@janko)

* Add the backup plugin for backing up stored files (@janko)

* Storages don't need to rewind the files after upload anymore (@janko)

* Make S3 presigns work when the `:endpoint` option is given (@NetsoftHoldings)

* Fix parallelize plugin to always work with the moving plugin (@janko)

* Fix S3 storage to handle copying files that are larger than 5GB (@janko)

* Add `:upload_options` to S3 storage for applying additional options on upload (@janko)

* Reduce length of URLs generated with pretty_location plugin (@gshaw)

## 1.0.0 (2015-11-27) [[release notes]](https://shrinerb.com/docs/release_notes/1.0.0)

* Improve Windows compatibility in the FileSystem storage (@janko)

* Remove the ability for FileSystem storage to accept IDs starting with a slash (@janko)

* Fix keep_files plugin requiring context for deleting files (@janko)

* Extract assigning cached files by parsed JSON into a parsed_json plugin (@janko)

* Add `(before|around|after)_upload` to the hooks plugin (@janko)

* Fix `S3#multi_delete` and `S3#clear!` not using the prefix (@janko)

* Add ability to pass presign options to storages in the direct_upload plugin (@janko)

* Remove `Shrine.io!` because it was actually meant to be only for internal use (@janko)

* Remove `Shrine.delete` because of redundancy (@janko)

* Add default_url_options plugin for specifiying default URL options for uploaded files (@janko)

* Add module_include plugin for easily extending core classes for given uploader (@janko)

* Add support for Sequel's Postgres JSON column support (@janko)

* Fix migration_helpers plugin not detecting when column changed (@janko)

* Add the `:public` option to S3 storage for retrieving public URLs which aren't signed (@janko)

* Remove the delete_invalid plugin, as it could cause lame errors (@janko)

* Don't delete cached files anymore, as it can cause errors with backgrounding (@janko)

* Add a `:host` option to the S3 storage for specifying CDNs (@janko)

* Don't allow same attachment to be promoted multiple times with backgrounding (@janko)

* Fix recache plugin causing an infinite loop (@janko)

* Fix an encoding error in determine_mime_type when using `:file` with non-files (@janko)

* Make `UploadedFile` actually delete itself only once (@janko)

* Make `UploadedFile#inspect` cleaner by showing only the data hash (@janko)

* Make determine_mime_type able to accept non-files when using :file (@janko)

* Make logging plugin accept PORO instance which don't have an #id (@janko)

* Add rack_file plugin for attaching Rack file hashes to models (@janko)
