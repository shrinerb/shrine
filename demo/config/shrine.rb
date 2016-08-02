require "./config/credentials"

require "shrine"
require "shrine/storage/s3"

require "./jobs/promote_job"
require "./jobs/delete_job"

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

Shrine.plugin :sequel
Shrine.plugin :backgrounding
Shrine.plugin :logging
Shrine.plugin :determine_mime_type
Shrine.plugin :direct_upload

Shrine::Attacher.promote { |data| PromoteJob.perform_async(data) }
Shrine::Attacher.delete { |data| DeleteJob.perform_async(data) }
