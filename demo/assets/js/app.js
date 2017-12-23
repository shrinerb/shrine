function fileUpload(fileInput) {
  var wrapper      = fileInput.parentNode
  var imagePreview = document.getElementById(fileInput.dataset.preview)

  var uppy = Uppy.Core({
    id: fileInput.id
  })

  uppy.use(Uppy.FileInput, {
    target:               wrapper,
    multipleFiles:        false,
    inputName:            'file',
    replaceTargetContent: true
  })

  if (fileInput.dataset.uploadServer == 's3') {
    uppy.use(Uppy.AwsS3, {
      getUploadParameters: function(file) {
        var queryString = '?filename=' + file.name.match(/[^\/\\]+$/)[0]

        return fetch('/presign' + queryString)
          .then(function(response) { return response.json() })
          .then(function(data) { return { method: "POST", url: data.url, fields: data.fields } })
      }
    })
  } else {
    uppy.use(Uppy.XHRUpload, {
      endpoint: '/upload',
      fieldName: 'file',
      headers: { 'X-CSRF-Token': document.querySelector('[name=_csrf]').value }
    })
  }

  uppy.use(Uppy.ProgressBar, {
    target: imagePreview.parentNode
  })

  uppy.run()

  uppy.on('upload-success', function(fileId, data) {
    // retrieve uppy's file object (`file.data` contains the actual JavaScript file object)
    var file = uppy.getFile(fileId)

    if (fileInput.dataset.uploadServer == 's3') {
      var uploadedFileData = JSON.stringify({
        id: file.meta['key'].match(/^cache\/(.+)/)[1], // remove the Shrine storage prefix
        storage: 'cache',
        metadata: {
          size:      file.size,
          filename:  file.name.match(/[^\/\\]+$/)[0],
          mime_type: file.type
        }
      })
    } else {
      var uploadedFileData = JSON.stringify(data)
    }

    // uppy's image preview doesn't work on Safari, so we use our own
    loadDataUri(file.data).then(function(dataUri) { imagePreview.src = dataUri })

    // set hidden field value to the uploaded file data so that it's submitted with the form as the attachment
    var hiddenInput = wrapper.parentNode.querySelector('input[type=hidden]')
    hiddenInput.value = uploadedFileData
  })

  return uppy;
}

document.querySelectorAll('form input[type=file]').forEach(function(fileInput) {
  if (fileInput.multiple) {
    fileInput.addEventListener('change', function(event) {
      var files = Array.prototype.slice.call(fileInput.files)

      files.forEach(function(file) {
        var newResource = document.querySelector('.templates .' + fileInput.dataset.template).cloneNode(true)
        newResource.innerHTML = newResource.innerHTML.replace(/<INDEX>/g, Date.now().toString())
        document.getElementById(fileInput.dataset.uploadList).appendChild(newResource)

        var resourceInputField = newResource.querySelector('input[type=file]')
        fileUpload(resourceInputField).addFile({name: file.name, type: file.type, data: file})
      })

      // remove selected files
      fileInput.value = ""
    })
  } else {
    fileUpload(fileInput)
  }
})

function loadDataUri(file) {
  return new Promise(function(resolve, reject) {
    var reader = new FileReader();
    reader.onload = function(e) { resolve(e.target.result); }
    reader.readAsDataURL(file);
  });
}
