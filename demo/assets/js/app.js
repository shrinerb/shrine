function fileUpload(wrapper, uploadServer) {
  var fileInput    = wrapper.querySelector('input[type=file]')
  var imagePreview = document.getElementById(wrapper.dataset.preview)

  var uppy = Uppy.Core({ id: fileInput.id })
    .use(Uppy.FileInput, {
      target:               wrapper,
      allowMultipleFiles:   false,
      replaceTargetContent: true
    })
    .use(Uppy.ProgressBar, {
      target: imagePreview.parentNode
    })

  if (uploadServer == 's3') {
    uppy.use(Uppy.AwsS3, {
      getUploadParameters: function(file) {
        return fetch('/presign?filename=' + file.name)
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

  uppy.run()

  uppy.on('upload-success', function(fileId, data) {
    // retrieve uppy's file object (`file.data` contains the actual JavaScript file object)
    var file = uppy.getFile(fileId)

    // show image preview (uppy's preview currently doesn't work on Safari, so we use our own)
    loadDataUri(file.data).then(function(dataUri) { imagePreview.src = dataUri })

    if (uploadServer == 's3') {
      // construct uploaded file data in the format that Shrine expects
      var uploadedFileData = JSON.stringify({
        id: file.meta['key'].match(/^cache\/(.+)/)[1], // remove the Shrine storage prefix
        storage: 'cache',
        metadata: {
          size:      file.size,
          filename:  file.name,
          mime_type: file.type,
        }
      })
    } else {
      var uploadedFileData = JSON.stringify(data)
    }

    // set hidden field value to the uploaded file data so that it's submitted with the form as the attachment
    var hiddenInput = wrapper.parentNode.querySelector('input[type=hidden]')
    hiddenInput.value = uploadedFileData
  })

  return uppy;
}

// single file upload
document.querySelectorAll('form .uppy-file-input').forEach(function(wrapper) {
  fileUpload(wrapper, wrapper.dataset.uploadServer)
})

// multiple file upload
document.querySelectorAll('form input[type=file][multiple]').forEach(function(fileInput) {
  fileInput.addEventListener('change', function(event) {
    // convert FileList to Array
    var files = Array.prototype.slice.call(fileInput.files)

    files.forEach(function(file) {
      // create a new copy of the resource for the selected file
      var newResource = document.querySelector('.templates .' + fileInput.dataset.template).cloneNode(true)
      newResource.innerHTML = newResource.innerHTML.replace(/<INDEX>/g, Date.now().toString())
      document.getElementById(fileInput.dataset.uploadList).appendChild(newResource)

      // trigger file upload on that resource
      var wrapper = newResource.querySelector('.uppy-file-input')
      var uppy = fileUpload(wrapper, wrapper.dataset.uploadServer)
      uppy.addFile({name: file.name, type: file.type, data: file})
    })

    // remove selected files
    fileInput.value = ""
  })
})

// load data URI of the image file
function loadDataUri(file) {
  return new Promise(function(resolve, reject) {
    var reader = new FileReader();
    reader.onload = function(e) { resolve(e.target.result); }
    reader.readAsDataURL(file);
  });
}
