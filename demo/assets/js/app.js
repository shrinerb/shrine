const singleFileUpload = (fileInput) => {
  const imagePreview = document.getElementById(fileInput.dataset.previewElement)
  const formGroup    = fileInput.parentNode

  formGroup.removeChild(fileInput)

  const uppy = fileUpload(fileInput)

  uppy
    .use(Uppy.FileInput, {
      target: formGroup,
      locale: { strings: { chooseFiles: 'Choose file' } },
    })
    .use(Uppy.Informer, {
      target: formGroup,
    })
    .use(Uppy.ProgressBar, {
      target: imagePreview.parentNode,
    })
    .use(Uppy.ThumbnailGenerator, {
      thumbnailWidth: 600,
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
    .use(Uppy.Dashboard, {
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
  const uppy = new Uppy.Core({
    id: fileInput.id,
    autoProceed: true,
    restrictions: {
      allowedFileTypes: fileInput.accept.split(','),
    },
  })

  if (fileInput.dataset.uploadServer == 's3') {
    uppy.use(Uppy.AwsS3, {
      companionUrl: '/', // will call Shrine's presign endpoint mounted on `/s3/params`
    })
  } else {
    uppy.use(Uppy.XHRUpload, {
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
      id: file.meta['key'].match(/^cache\/(.+)/)[1], // object key without prefix
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
