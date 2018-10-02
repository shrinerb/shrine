// This code uses:
//
// * babel-polyfill (https://babeljs.io/docs/usage/polyfill/)
// * whatwg-fetch (https://github.github.io/fetch/)
// * uppy (https://uppy.io)

function fileUpload(fileInput) {
  var imagePreview = document.getElementById(fileInput.dataset.previewElement)

  fileInput.style.display = 'none' // uppy will add its own file input

  var uppy = Uppy.Core({
      id: fileInput.id,
      restrictions: {
        allowedFileTypes: fileInput.accept.split(','),
      },
    })
    .use(Uppy.FileInput, {
      target: fileInput.parentNode,
    })
    .use(Uppy.Informer, {
      target: fileInput.parentNode,
    })
    .use(Uppy.ProgressBar, {
      target: imagePreview.parentNode,
    })

  if (fileInput.dataset.uploadServer == 's3') {
    uppy.use(Uppy.AwsS3, {
      getUploadParameters: function (file) {
        // Shrine's presign endpoint
        return fetch('/presign?filename=' + file.name + '&type=' + file.type, {
          credentials: 'same-origin', // send cookies
        }).then(function (response) { return response.json() })
      }
    })
  } else {
    uppy.use(Uppy.XHRUpload, {
      endpoint: '/upload', // Shrine's upload endpoint
      fieldName: 'file',
      headers: { 'X-CSRF-Token': fileInput.dataset.uploadCsrfToken }
    })
  }

  uppy.on('upload-success', function (file, data) {
    // show image preview
    imagePreview.src = URL.createObjectURL(file.data)

    if (fileInput.dataset.uploadServer == 's3') {
      // construct uploaded file data in the format that Shrine expects
      var uploadedFileData = JSON.stringify({
        id: data['key'].match(/^cache\/(.+)/)[1], // object key without prefix
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
    var hiddenInput = document.getElementById(fileInput.dataset.uploadResultElement)
    hiddenInput.value = uploadedFileData
  })

  return uppy
}

document.querySelectorAll('input[type=file]').forEach(function (fileInput) {
  if (fileInput.multiple) {
    fileInput.addEventListener('change', function (event) {
      Array.from(fileInput.files).forEach(function (file) {
        // create a new copy of the resource for the selected file
        var template = document.getElementById(fileInput.dataset.template)
        var uploadList = document.getElementById(fileInput.dataset.uploadList)
        var uniqueId = Date.now().toString(36) + Math.random().toString(36).substr(2, 9)
        uploadList.insertAdjacentHTML('beforeend', template.innerHTML.replace(/{{index}}/g, uniqueId))

        // trigger file upload on the new resource
        var singleFileInput = uploadList.lastElementChild.querySelector('input[type=file]')
        var uppy = fileUpload(singleFileInput)
        uppy.addFile({name: file.name, type: file.type, data: file})
      })

      // remove selected files
      fileInput.value = ''
    })
  } else {
    fileUpload(fileInput)
  }
})
