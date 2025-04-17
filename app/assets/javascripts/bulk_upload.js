function initializeBulkUpload() {
  const dropZone = document.getElementById('drop-zone');
  const fileInput = document.getElementById('file-input');
  const browseButton = document.getElementById('browse-files');
  const fileList = document.getElementById('file-list');
  const nextStepButton = document.getElementById('next-step');

  if (!dropZone || !fileInput || !browseButton || !fileList || !nextStepButton) {
    return;
  }

  dropZone.replaceWith(dropZone.cloneNode(true));
  fileInput.replaceWith(fileInput.cloneNode(true));
  browseButton.replaceWith(browseButton.cloneNode(true));
  nextStepButton.replaceWith(nextStepButton.cloneNode(true));

  const newDropZone = document.getElementById('drop-zone');
  const newFileInput = document.getElementById('file-input');
  const newBrowseButton = document.getElementById('browse-files');
  const newNextStepButton = document.getElementById('next-step');

  const MAX_UPLOADS = 200;
  const allowedExtensions = ['jpg', 'jpeg', 'png']; // Allowed file extensions (removed gif, bmp)
  let totalFilesAdded = 0;
  let uploadCount = 0;
  let completedCount = 0;
  const uploadedFilenames = new Set();
  let validFiles = []; // Track valid files for submission

  newBrowseButton.addEventListener('click', () => {
    newFileInput.click();
  });

  newDropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    newDropZone.classList.add('dragover');
  });

  newDropZone.addEventListener('dragleave', () => {
    newDropZone.classList.remove('dragover');
  });

  newDropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    newDropZone.classList.remove('dragover');
    handleFiles(e.dataTransfer.files);
  });

  newFileInput.addEventListener('change', () => {
    handleFiles(newFileInput.files);
    newFileInput.value = ''; // Clear the input after processing
  });

  newNextStepButton.addEventListener('click', () => {
    window.location.href = `/symbolsets/${window.symbolsetSlug}/metadata`;
  });

  function handleFiles(files) {
    const remainingCapacity = MAX_UPLOADS - totalFilesAdded;
    if (files.length > remainingCapacity) {
      if (remainingCapacity > 0) {
        alert(`You can only upload a maximum of ${MAX_UPLOADS} images per page load. ` +
              `You've already added ${totalFilesAdded} files. ` +
              `Please select ${remainingCapacity} or fewer additional files.`);
      } else {
        alert(`You’ve reached the maximum of ${MAX_UPLOADS} images per page load. ` +
              `Refresh the page to start over.`);
      }
      return;
    }

    const filesArray = Array.from(files);
    const rejectedFiles = [];

    // Validate file extensions
    const newValidFiles = filesArray.filter(file => {
      const fileExtension = file.name.split('.').pop().toLowerCase();
      if (fileExtension === 'svg' || fileExtension === 'bmp' || fileExtension === 'gif') {
        rejectedFiles.push(file.name);
        return false;
      }
      if (!allowedExtensions.includes(fileExtension)) {
        rejectedFiles.push(file.name);
        return false;
      }
      if (uploadedFilenames.has(file.name)) {
        displayFileStatus(file.name, 'error', 'Duplicate filenames are not allowed in one session.');
        return false;
      }
      return true;
    });

    if (newValidFiles.length === 0) {
      if (rejectedFiles.length > 0) {
        displayRejectedFiles(rejectedFiles);
      }
      return;
    }

    // Add valid files to the global list
    validFiles = [...validFiles, ...newValidFiles];
    totalFilesAdded += newValidFiles.length;
    uploadCount += newValidFiles.length;

    newValidFiles.forEach(file => {
      uploadedFilenames.add(file.name);
      displayFileStatus(file.name, 'uploading');
      uploadFile(file);
    });

    if (rejectedFiles.length > 0) {
      displayRejectedFiles(rejectedFiles);
    }
  }

  function displayFileStatus(fileName, status, customMessage) {
    const fileItem = document.createElement('div');
    fileItem.className = 'file-item';
    fileItem.setAttribute('data-filename', fileName); // Add identifier for easier lookup
    let icon = '';
    let message = status;
    if (status === 'uploading') {
      icon = '<i class="fas fa-spinner fa-spin"></i>';
    } else if (status === 'success') {
      icon = '<i class="fas fa-check" style="color: green;"></i>';
      message = 'Uploaded successfully';
    } else if (status === 'error') {
      icon = '<i class="fas fa-exclamation-triangle" style="color: red;"></i>';
      message = customMessage ? `error - ${customMessage}` : 'error - Upload failed';
    }
    fileItem.innerHTML = `<span>${fileName}</span><span class="status">${icon} ${message}</span>`;
    fileList.appendChild(fileItem);
  }

  function displayRejectedFiles(rejectedFiles) {
    const errorMessage = document.createElement('div');
    errorMessage.className = 'error-message';
    errorMessage.innerHTML = `The following files were rejected (SVG, BMP, and GIF files are not allowed): ${rejectedFiles.join(', ')}`;
    fileList.appendChild(errorMessage);
  }

  async function uploadFile(file) {
    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await fetch(`/symbolsets/${window.symbolsetId}/bulk_symbols`, {
        method: 'POST',
        body: formData,
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content // Include CSRF token for Rails
        }
      });

      const data = await response.json();

      completedCount++;
      if (response.ok && data.status === 'success') {
        updateFileStatus(file.name, 'success');
      } else if (data.status === 'error' && data.errors) {
        const errorMessage = data.errors.join('; ');
        updateFileStatus(file.name, 'error', errorMessage);
      } else {
        updateFileStatus(file.name, 'error', 'Upload failed');
      }
    } catch (error) {
      completedCount++;
      let errorMessage = 'Upload failed';
      if (error.response) {
        try {
          const data = await error.response.json();
          if (data && data.errors) {
            errorMessage = Array.isArray(data.errors) ? data.errors.join('; ') : data.errors.toString();
          } else {
            errorMessage = 'Upload failed - Invalid server response';
          }
        } catch (e) {
          errorMessage = 'Upload failed - Unable to parse server response';
        }
      } else {
        errorMessage = 'Upload failed - Network error';
      }
      setTimeout(() => {
        updateFileStatus(file.name, 'error', errorMessage);
      }, 0);
    }
    checkAllUploadsComplete();
  }

  function updateFileStatus(fileName, status, customMessage) {
    const items = fileList.getElementsByClassName('file-item');
    let found = false;
    for (let item of items) {
      if (item.getAttribute('data-filename') === fileName) {
        let icon = status === 'success'
          ? '<i class="fas fa-check" style="color: green;"></i>'
          : '<i class="fas fa-exclamation-triangle" style="color: red;"></i>';
        let message = status === 'success'
          ? 'Uploaded successfully'
          : (customMessage ? `error - ${customMessage}` : 'error - Upload failed');
        const statusElement = item.querySelector('.status');
        if (statusElement) {
          statusElement.innerHTML = `${icon} ${message}`;
        }
        found = true;
        break;
      }
    }
    if (!found) {
      console.error('File item not found for:', fileName);
    }
  }

  function checkAllUploadsComplete() {
    if (completedCount === uploadCount) {
      newNextStepButton.disabled = false;
    }
  }
}

document.addEventListener('DOMContentLoaded', initializeBulkUpload);
document.addEventListener('turbolinks:load', initializeBulkUpload);
