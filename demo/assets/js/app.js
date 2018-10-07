import Uppy from '@uppy/core'
import FileInput from '@uppy/file-input'
import Informer from '@uppy/informer'
import ProgressBar from '@uppy/progress-bar'
import AwsS3 from '@uppy/aws-s3'
import XHRUpload from '@uppy/xhr-upload'
import uuid from 'uuid'

import '@babel/polyfill'
import 'whatwg-fetch'

const fileUpload = fileInput => {
  const imagePreview = document.getElementById(fileInput.dataset.previewElement)

  fileInput.style.display = 'none' // uppy will add its own file input

  const uppy = Uppy({
      id: fileInput.id,
      restrictions: {
        allowedFileTypes: fileInput.accept.split(','),
      },
    })
    .use(FileInput, {
      target: fileInput.parentNode,
    })
    .use(Informer, {
      target: fileInput.parentNode,
    })
    .use(ProgressBar, {
      target: imagePreview.parentNode,
    })

  if (fileInput.dataset.uploadServer == 's3') {
    uppy.use(AwsS3, {
      getUploadParameters: async (file) => {
        // Shrine's presign endpoint
        const response = await fetch(`/presign?filename=${file.name}&type=${file.type}`, {
          credentials: 'same-origin', // send cookies
        })
        return response.json()
      }
    })
  } else {
    uppy.use(XHRUpload, {
      endpoint: '/upload', // Shrine's upload endpoint
      fieldName: 'file',
      headers: { 'X-CSRF-Token': fileInput.dataset.uploadCsrfToken }
    })
  }

  uppy.on('upload-success', (file, data) => {
    // show image preview
    imagePreview.src = URL.createObjectURL(file.data)

    if (fileInput.dataset.uploadServer == 's3') {
      // construct uploaded file data in the format that Shrine expects
      const uploadedFileData = {
        id: file.meta['key'].match(/^cache\/(.+)/)[1], // object key without prefix
        storage: 'cache',
        metadata: {
          size:      file.size,
          filename:  file.name,
          mime_type: file.type,
        }
      }
    } else {
      const uploadedFileData = data
    }

    // set hidden field value to the uploaded file data so that it's submitted with the form as the attachment
    const hiddenInput = document.getElementById(fileInput.dataset.uploadResultElement)
    hiddenInput.value = JSON.stringify(uploadedFileData)
  })

  return uppy
}

document.querySelectorAll('input[type=file]').forEach(fileInput => {
  if (fileInput.multiple) {
    fileInput.addEventListener('change', event => {
      Array.from(fileInput.files).forEach(file => {
        // create a new copy of the resource for the selected file
        const template = document.getElementById(fileInput.dataset.template)
        const uploadList = document.getElementById(fileInput.dataset.uploadList)
        uploadList.insertAdjacentHTML('beforeend', template.innerHTML.replace(/{{index}}/g, uuid()))

        const singleFileInput = uploadList.lastElementChild.querySelector('input[type=file]')
        const uppy = fileUpload(singleFileInput)
        // trigger file upload on the new resource
        uppy.addFile({name: file.name, type: file.type, data: file})
      })

      // remove selected files
      fileInput.value = ''
    })
  } else {
    fileUpload(fileInput)
  }
})
