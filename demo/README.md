# Shrine demo using Roda & Sequel

This is a Roda & Sequel demo for [Shrine]. It demonstrates how easy it is to
implement complex file upload flow with [Shrine]. It allows the user to add or
remove photos.

Uploading:

1. User selects one or more files
2. They asynchronously upload directly to S3 (with a progress bar)
3. Photo records are created with (temporarily stored) images
4. Background job starts processing and permanently storing images
5. On finishing it updates the record with original image and its thumbnail

Deleting:

1. User marks photos for deletion and submits
2. Deletion starts in background, and form submits instantly
3. Background job finishes deleting

This is generally the best user experience for file uploads, because everything
is done asynchronously, the user doesn't have to wait for processing, and
they're completely unaware of background jobs.

It is also great peformance-wise, since your app doesn't have to accept file
uploads (files are uploaded directly to S3), and it isn't blocked by
processing, storing or deleting.

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

[Shrine]: https://github.com/janko-m/shrine
[setup CORS]: http://docs.aws.amazon.com/AmazonS3/latest/dev/cors.html
