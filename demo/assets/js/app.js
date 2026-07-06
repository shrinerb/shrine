import { Uppy, Dashboard, StatusBar, ThumbnailGenerator, AwsS3, XHRUpload } from "uppy"

const singleFileUpload = (fileInput) => {
  const imagePreview = document.getElementById(fileInput.dataset.previewElement)

  const uppy = fileUpload(fileInput)

  uppy
    .use(StatusBar, {
      target: imagePreview.parentNode,
      hideUploadButton: true,
    })
    .use(ThumbnailGenerator, {
      thumbnailWidth: 600,
    })

  // Uppy 5 removed the FileInput plugin, so we keep the native file input and
  // hand its selected files to Uppy ourselves (`autoProceed` uploads them right away).
  fileInput.addEventListener('change', (event) => {
    Array.from(event.target.files).forEach((file) => {
      try {
        uppy.addFile(file)
      } catch (error) {
        if (!error.isRestriction) throw error // ignore `allowedFileTypes` rejections
      }
    })
    event.target.value = null // allow selecting the same file again
  })

  uppy.on('upload-success', (file, response) => {
    // set hidden field value to the uploaded file data so that it's submitted with the form as the attachment
    const hiddenInput = document.getElementById(fileInput.dataset.uploadResultElement)
    hiddenInput.value = uploadedFileData(file, response, fileInput)
  })

  uppy.on('thumbnail:generated', (file, preview) => {
    imagePreview.src = preview
  })
}

const multipleFileUpload = (fileInput) => {
  var formGroup = fileInput.parentNode

  var uppy = fileUpload(fileInput)

  uppy
    .use(Dashboard, {
      target: formGroup,
      inline: true,
      height: 300,
      replaceTargetContent: true,
    })

  uppy.on('upload-success', (file, response) => {
    const hiddenField = document.createElement('input')

    hiddenField.type = 'hidden'
    hiddenField.name = 'album[photos_attributes]['+ Math.random().toString(36).substr(2, 9) + '][image]'
    hiddenField.value = uploadedFileData(file, response, fileInput)

    document.querySelector('form').appendChild(hiddenField)
  })
}

const fileUpload = (fileInput) => {
  const uppy = new Uppy({
    id: fileInput.id,
    autoProceed: true,
    restrictions: {
      allowedFileTypes: fileInput.accept.split(','),
    },
  })

  if (fileInput.dataset.uploadServer == 's3') {
    uppy.use(AwsS3, {
      // will call Shrine's presign endpoint mounted on `/s3/params`
      endpoint: '/',
      shouldUseMultipart: false,
    })
  } else {
    uppy.use(XHRUpload, {
      endpoint: '/upload', // Shrine's upload endpoint
      headers: { 'X-CSRF-Token': fileInput.dataset.uploadCsrfToken }
    })
  }

  return uppy
}

const uploadedFileData = (file, response, fileInput) => {
  if (fileInput.dataset.uploadServer == 's3') {
    // construct uploaded file data in the format that Shrine expects
    return JSON.stringify({
      // Uppy stores the presigned S3 object key on `file.s3Multipart.key`
      id: file.s3Multipart.key.match(/^cache\/(.+)/)[1], // object key without prefix
      storage: 'cache',
      metadata: {
        size:      file.size,
        filename:  file.name,
        mime_type: file.type,
      }
    })
  } else {
    return JSON.stringify(response.body)
  }
}

document.querySelectorAll('input[type=file]').forEach((fileInput) => {
  if (fileInput.multiple) {
    multipleFileUpload(fileInput)
  } else {
    singleFileUpload(fileInput)
  }
})
