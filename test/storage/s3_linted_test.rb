require "test_helper"
require "shrine/storage/s3"
require "shrine/storage/linter"

# To run the Linter against Shrine::Storage::S3, you need an actual S3 bucket or
# fascimile thereof. So these tests are not run by default. They are only run
# if you set certain ENV variables -- in .travis.yml, we DO run, but against
# a minio server (https://github.com/minio/minio) rather than a real S3 bucket.
#
# You can set S3_LINTED_TEST=true, and set relevant other ENV variables
# for appropriate S3 access -- or something API compatible with S3, like minio.
#
# S3_LINTED_TEST=true
#
# S3_BUCKET
# S3_ACCESS_KEY_ID
# S3_SECRET_ACCESS_KEY
# S3_ENDPOINT           # not needed for real S3
# S3_REGION             # needed but ignored for minio


if ENV['S3_LINTED_TEST'] == "true"
  describe Shrine::Storage::S3 do
    def s3(**options)
      options = {
        bucket: ENV['S3_BUCKET'],
        access_key_id: ENV['S3_ACCESS_KEY_ID'],
        secret_access_key: ENV['S3_SECRET_ACCESS_KEY'],
        endpoint: ENV['S3_ENDPOINT'],
        # we usually need to force_path_style if not real S3
        force_path_style: (!!ENV['S3_ENDPOINT']),
        region: ENV['S3_REGION']
      }.compact.merge(options)

      Shrine::Storage::S3.new(**options)
    end

    it "passes the linter" do
      Shrine::Storage::Linter.new(s3).call
      Shrine::Storage::Linter.new(s3(prefix: "uploads")).call
      assert true
    end
  end
end
