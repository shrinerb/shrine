# Shrine demo using Roda & Sequel

*(Looking for the Rails version - see the [Rails demo]. Before you head over there, give this demo a try. Roda is just as capable as Rails without the bloat and super flexible on a per route basis because you only add on what you need! One thing to note - Roda places Rails controller-like code in routes because it's route centric, the rest is pretty similar to Rails.)*

This is a Roda & Sequel demo for [Shrine]. It allows the user to create albums and attach images. The demo shows an advanced workflow:

Uploading:

1. User selects one or more files
2. The files get asynchronously uploaded directly to S3 and a progress bar is displayed
3. The cached file data gets written to the hidden fields
4. Once the form is submitted, background jobs are kicked off to process the images
5. The records are saved with cached files, which are shown as fallback
6. Once background jobs are finished, records are updated with processed attachment data

Deleting:

1. User marks photos for deletion and submits
2. Deletion starts in background, and form submits instantly
3. Background job finishes deleting

This asynchronicity generally provides an ideal user experience, because the
user doesn't have to wait for processing or deleting, and due to fallbacks
they can be unaware of background jobs.

Direct uploads and backgrounding also have performance advantages, since your
app doesn't have to receive file uploads (as files are uploaded directly to S3),
and the web workers aren't blocked by processing, storing or deleting.

## Implementation

In production environment files are uploaded directly to S3, while in
development and test environment they are uploaded to the app and stored on
disk. The demo features both single and multiple uploads.

On the client side [Uppy] is used for handling file uploads. The complete
JavaScript implementation for the demo can be found in
[app.js](/demo/assets/js/app.js).

Files of interest:
* [app.rb]
* [config/shrine.rb]
* [jobs/delete_job.rb]
* [jobs/promote_job.rb]
* [uploaders/image_uploader.rb]
* [db/migrations/001_create_albums.rb]
* [db/migrations/002_create_photos.rb]
* [models/album.rb]
* [models/photo.rb]
* [routes/albums.rb]
* [routes/direct_upload.rb]
* [views/\*]

## Requirements

To run the app you need to setup the following things:

* Install ImageMagick:

  ```rb
  $ brew install imagemagick
  ```

* Install the gems:

  ```rb
  $ bundle install
  ```

* Have SQLite on your machine, and run

  ```sh
  $ sequel -m db/migrations sqlite://database.sqlite3
  ```

* Put your Amazon S3 credentials in `.env` and [setup CORS].

  ```sh
  S3_ACCESS_KEY_ID="..."
  S3_SECRET_ACCESS_KEY="..."
  S3_REGION="..."
  S3_BUCKET="..."
  ```

Once you have all of these things set up, you can run the app:

```sh
$ bundle exec rackup
```

[Shrine]: https://github.com/shrinerb/shrine
[setup CORS]: http://docs.aws.amazon.com/AmazonS3/latest/dev/cors.html
[Uppy]: https://uppy.io
[Rails demo]: https://github.com/erikdahlstrand/shrine-rails-example
[app.rb]: /demo/app.rb
[config/shrine.rb]: /demo/config/shrine.rb
[jobs/delete_job.rb]: /demo/jobs/delete_job.rb
[jobs/promote_job.rb]: /demo/jobs/promote_job.rb
[uploaders/image_uploader.rb]: /demo/uploaders/image_uploader.rb
[db/migrations/001_create_albums.rb]: /demo/db/migrations/001_create_albums.rb
[db/migrations/002_create_photos.rb]: /demo/db/migrations/002_create_photos.rb
[models/album.rb]: /demo/models/album.rb
[models/photo.rb]: /demo/models/photo.rb
[routes/albums.rb]: /demo/routes/albums.rb
[routes/direct_upload.rb]: /demo/routes/direct_upload.rb
[views/\*]: /demo/views/
