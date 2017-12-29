// This code uses:
//
// * babel-polyfill (https://babeljs.io/docs/usage/polyfill/)
// * whatwg-fetch (https://github.github.io/fetch/)
// * uppy (https://uppy.io)

function fileUpload(fileInput) {
  var imagePreview = document.getElementById(fileInput.dataset.previewElement)

  fileInput.style.display = 'none' // uppy will add its own file input

  var uppy = Uppy.Core({ id: fileInput.id, thumbnailGeneration: false })
    .use(Uppy.FileInput, {
      target:             fileInput.parentNode,
      allowMultipleFiles: fileInput.multiple
    })
    .use(Uppy.ProgressBar, {
      target: imagePreview.parentNode
    })

  if (fileInput.dataset.uploadServer == 's3') {
    uppy.use(Uppy.AwsS3, {
      getUploadParameters: function (file) {
        return fetch('/presign?filename=' + file.name) // Shrine's presign endpoint
          .then(function (response) { return response.json() })
          .then(function (data) { return { method: "POST", url: data.url, fields: data.fields } })
      }
    })
  } else {
    uppy.use(Uppy.XHRUpload, {
      endpoint: '/upload', // Shrine's upload endpoint
      fieldName: 'file',
      headers: { 'X-CSRF-Token': document.querySelector('meta[name=_csrf]').content }
    })
  }

  uppy.run()

  uppy.on('upload-success', function (fileId, data) {
    // retrieve uppy's file object (`file.data` contains the actual JavaScript File object)
    var file = uppy.getFile(fileId)

    // show image preview
    imagePreview.src = file.preview

    if (fileInput.dataset.uploadServer == 's3') {
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
        uploadList.insertAdjacentHTML('beforeend', template.innerHTML.replace(/{{index}}/g, Date.now()))

        // trigger file upload on the new resource
        var singleFileInput = uploadList.lastElementChild.querySelector('input[type=file]')
        var uppy = fileUpload(singleFileInput)
        uppy.addFile({name: file.name, type: file.type, data: file})
      })

      // remove selected files
      fileInput.value = ""
    })
  } else {
    fileUpload(fileInput)
  }
})
