require "./config/credentials"

require "shrine"

require "./jobs/promote_job"
require "./jobs/delete_job"

if ENV["RACK_ENV"] == "production"
  require "shrine/storage/s3"

  s3_options = {
    bucket:            ENV.fetch("S3_BUCKET"),
    region:            ENV.fetch("S3_REGION"),
    access_key_id:     ENV.fetch("S3_ACCESS_KEY_ID"),
    secret_access_key: ENV.fetch("S3_SECRET_ACCESS_KEY"),
  }

  Shrine.storages = {
    cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
    store: Shrine::Storage::S3.new(prefix: "store", **s3_options),
  }
else
  require "shrine/storage/file_system"

  Shrine.storages = {
    cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
    store: Shrine::Storage::FileSystem.new("public", prefix: "uploads/store"),
  }
end

Shrine.plugin :sequel
Shrine.plugin :backgrounding
Shrine.plugin :logging
Shrine.plugin :determine_mime_type
Shrine.plugin :cached_attachment_data
Shrine.plugin :restore_cached_data
Shrine.plugin :presign_endpoint if ENV["RACK_ENV"] == "production"
Shrine.plugin :upload_endpoint if ENV["RACK_ENV"] != "production"

Shrine::Attacher.promote { |data| PromoteJob.perform_async(data) }
Shrine::Attacher.delete { |data| DeleteJob.perform_async(data) }
