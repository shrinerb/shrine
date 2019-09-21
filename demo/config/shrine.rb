# This is a general base configuration for Shrine in the app.
# It's typically placed in a `config` and/or `initializers` folder.

require "./config/credentials"
require "shrine"
require "dry-monitor"

# needed by `backgrounding` plugin
require "./jobs/promote_job"
require "./jobs/destroy_job"

# use S3 for production and local file for other environments
if ENV["RACK_ENV"] == "production"
  require "shrine/storage/s3"

  s3_options = {
    bucket:            ENV.fetch("S3_BUCKET"),
    region:            ENV.fetch("S3_REGION"),
    access_key_id:     ENV.fetch("S3_ACCESS_KEY_ID"),
    secret_access_key: ENV.fetch("S3_SECRET_ACCESS_KEY"),
  }

  # both `cache` and `store` storages are needed
  Shrine.storages = {
    cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
    store: Shrine::Storage::S3.new(**s3_options),
  }
else
  require "shrine/storage/file_system"

  # both `cache` and `store` storages are needed
  Shrine.storages = {
    cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
    store: Shrine::Storage::FileSystem.new("public", prefix: "uploads"),
  }
end

Shrine.plugin :sequel
Shrine.plugin :instrumentation, notifications: Dry::Monitor::Notifications.new(:test)
Shrine.plugin :determine_mime_type, analyzer: :marcel, log_subscriber: nil
Shrine.plugin :cached_attachment_data
Shrine.plugin :restore_cached_data
Shrine.plugin :derivation_endpoint, secret_key: "secret"
Shrine.plugin :derivatives

if ENV["RACK_ENV"] == "production"
  Shrine.plugin :presign_endpoint, presign_options: -> (request) {
    # Uppy will send the "filename" and "type" query parameters
    filename = request.params["filename"]
    type     = request.params["type"]

    {
      content_disposition:    ContentDisposition.inline(filename), # set download filename
      content_type:           type,                                # set content type
      content_length_range:   0..(10*1024*1024),                   # limit upload size to 10 MB
    }
  }
else
  Shrine.plugin :upload_endpoint
end

# delay promoting and deleting files to a background job (`backgrounding` plugin)
Shrine.plugin :backgrounding
Shrine::Attacher.promote_block do
  PromoteJob.perform_async(record.class, record.id, name, file_data)
end
Shrine::Attacher.destroy_block do
  DestroyJob.perform_async(self.class, data)
end
