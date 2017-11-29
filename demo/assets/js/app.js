document.addEventListener('change', function(e) {
  if (e.target.type !== 'file') return;

  var fileInput = e.target;
  var formGroup = fileInput.parentNode;
  var files     = Array.prototype.slice.call(fileInput.files); // convert FileList into an Array

  files.forEach(function(file) {
    var progressBar = document.querySelector('.templates .progress').cloneNode(true);

    // add progress bar to the DOM
    formGroup.insertBefore(progressBar, fileInput.nextSibling);

    var uploader = new Uploader(fileInput.dataset.uploadServer, {
      presignEndpoint: "/presign",                             // for S3 uploads
      uploadEndpoint: "/upload",                               // for uploads to the app
      csrfToken: document.querySelector('[name=_csrf]').value, // for uploads to the app
      onProgress: function(progressEvent) {
        // update progress bar with upload progress
        var progress = parseInt(progressEvent.loaded / progressEvent.total * 100, 10);
        var percentage = progress.toString() + '%';
        progressBar.querySelector('.progress-bar').style = 'width: ' + percentage;
        progressBar.querySelector('.progress-bar').innerHTML = percentage;
      }
    });

    uploader.upload(file)
      .then(function(uploadedFileData) {
        // remove progress bar
        formGroup.removeChild(progressBar);

        if (fileInput.multiple) { // MULTIPLE UPLOAD
          // create a new resource and replace the "<INDEX>" placeholder with a unique identifier (current timestamp)
          var newResource = document.querySelector('.templates .' + fileInput.dataset.template).cloneNode(true);
          newResource.innerHTML = newResource.innerHTML.replace(/<INDEX>/g, Date.now().toString());

          // populate img tag src with data URI of the image for preview
          var resourceInputField = newResource.querySelector('.file-upload-field[type=file]');
          var imagePreview = document.getElementById(resourceInputField.dataset.preview);
          loadDataUri(file).then(function(dataUri) { imagePreview.src = dataUri });

          // set hidden field value to the uploaded file data so that it's submitted with the form as the attachment
          var hiddenInput = newResource.querySelector('.file-upload-field[type=hidden]');
          hiddenInput.value = uploadedFileData;

          // append the new resource to the associated list
          document.getElementByid(fileInput.dataset.uploadList).appendChild(newResource);
        } else { // SINGLE UPLOAD
          // populate img tag src with data URI of the image for preview
          var imagePreview = document.getElementById(fileInput.dataset.preview);
          loadDataUri(file).then(function(dataUri) { imagePreview.src = dataUri });

          // set hidden field value to the uploaded file data so that it's submitted with the form as the attachment
          var hiddenInput = formGroup.querySelector('.file-upload-field[type=hidden]');
          hiddenInput.value = uploadedFileData;
        }
      })
      .catch(function(error) { alert('Error: ' + error.message) });
  });

  // remove selected files
  fileInput.value = "";
});

// Upload class which uses Axios for making HTTP requests
function Uploader (uploadServer, options) {
  this.uploadServer    = uploadServer;
  this.onProgress      = options.onProgress;
  this.csrfToken       = options.csrfToken;
  this.presignEndpoint = options.presignEndpoint;
  this.uploadEndpoint  = options.uploadEndpoint;
}

Uploader.prototype.upload = function(file) {
  if (this.uploadServer === 's3') return this.uploadToS3(file);
  else                            return this.uploadToApp(file);
}

Uploader.prototype.uploadToS3 = function(file) {
  var self = this;

  return this.fetchPresign(file)
    .then(function(presign) { return self.sendToS3(file, presign) })
    .then(function(key) {
      return JSON.stringify({
        id: key.match(/^cache\/(.+)/)[1], // we have to remove the Shrine storage prefix
        storage: 'cache',
        metadata: {
          size:      file.size,
          filename:  file.name.match(/[^\/\\]+$/)[0],
          mime_type: file.type
        }
      });
    });
}

Uploader.prototype.uploadToApp = function(file) {
  return this.sendToApp(file)
    .then(function(data) { return JSON.stringify(data) });
}

Uploader.prototype.fetchPresign = function(file) {
  return axios.get(this.presignEndpoint, {
      params:       { filename: file.name.match(/[^\/\\]+$/)[0] },
      responseType: 'json'
    })
    .then(function(response) { return response.data });
}

Uploader.prototype.sendToS3 = function(file, presign) {
  var uploadAxios = this.uploadAxios({
    data: presign['fields'],
    headers: presign['headers'],
  });

  return uploadAxios.post(presign['url'], { file: file })
    .then(function(response) { return presign['fields']['key'] });
}

Uploader.prototype.sendToApp = function(file) {
  var uploadAxios = this.uploadAxios({
    data: { _csrf: this.csrfToken },
    responseType: 'json'
  });

  return uploadAxios.post(this.uploadEndpoint, { file: file })
    .then(function(response) { return response.data });
}

Uploader.prototype.uploadAxios = function (options) {
  options.transformRequest = function (data, headers) {
    headers['Content-Type'] = 'multipart/form-data';
    return formData(data);
  };
  options.onUploadProgress = this.OnProgress;

  return axios.create(options);
}

function formData(object) {
  var formData = new FormData();
  Object.keys(object).forEach(function(key) { formData.append(key, object[key]) });
  return formData;
}

function loadDataUri(file) {
  return new Promise(function(resolve, reject) {
    var reader = new FileReader();
    reader.onload = function(e) { resolve(e.target.result); }
    reader.readAsDataURL(file);
  });
}
