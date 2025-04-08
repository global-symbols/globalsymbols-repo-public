// app/assets/javascripts/bulk_upload.js
document.addEventListener('DOMContentLoaded', () => {
  // Ensure this code only runs once by checking for a flag
  if (window.bulkUploadInitialized) return;
  window.bulkUploadInitialized = true;

  const dropZone = document.getElementById('drop-zone');
  const fileInput = document.getElementById('file-input');
  const browseButton = document.getElementById('browse-files');
  const fileList = document.getElementById('file-list');
  const nextStepButton = document.getElementById('next-step');
  let uploadCount = 0; // Total number of files to upload across all batches
  let completedCount = 0; // Total number of completed uploads

  // Guard clause: Exit if required elements are not found (e.g., on a different page)
  if (!dropZone || !fileInput || !browseButton || !fileList || !nextStepButton) {
    return;
  }

  // Remove existing event listeners to prevent duplicates (if any)
  const browseButtonClone = browseButton.cloneNode(true);
  browseButton.parentNode.replaceChild(browseButtonClone, browseButton);
  const fileInputClone = fileInput.cloneNode(true);
  fileInput.parentNode.replaceChild(fileInputClone, fileInput);

  // Reassign elements after cloning
  const newBrowseButton = document.getElementById('browse-files');
  const newFileInput = document.getElementById('file-input');

  // Trigger file input click when "Browse Files" is clicked
  newBrowseButton.addEventListener('click', () => {
    console.log('Browse Files button clicked'); // Debug log
    newFileInput.click();
  });

  // Handle drag-and-drop events
  dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('dragover');
  });

  dropZone.addEventListener('dragleave', () => {
    dropZone.classList.remove('dragover');
  });

  dropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('dragover');
    handleFiles(e.dataTransfer.files);
  });

  // Handle file input change
  newFileInput.addEventListener('change', () => {
    console.log('File input changed, files:', newFileInput.files); // Debug log
    handleFiles(newFileInput.files);
    // Clear the file input to prevent duplicate uploads
    newFileInput.value = '';
  });

  function handleFiles(files) {
    // Increment the total upload count with the new batch of files
    uploadCount += files.length;

    Array.from(files).forEach((file) => {
      displayFileStatus(file.name, 'uploading');
      uploadFile(file);
    });
  }

  function displayFileStatus(fileName, status) {
    const fileItem = document.createElement('div');
    fileItem.className = 'file-item';
    let icon = '';
    if (status === 'uploading') {
      icon = '<i class="fas fa-spinner fa-spin"></i>';
    } else if (status === 'success') {
      icon = '<i class="fas fa-check" style="color: green;"></i>';
    } else if (status === 'error') {
      icon = '<i class="fas fa-exclamation-triangle" style="color: red;"></i>';
    }
    fileItem.innerHTML = `
      <span>${fileName}</span>
      <span class="status">${icon} ${status}</span>
    `;
    fileList.appendChild(fileItem);
  }

  function uploadFile(file) {
    const formData = new FormData();
    formData.append('file', file);

    Rails.ajax({
      url: `/symbolsets/${window.symbolsetId}/bulk_symbols`,
      type: 'POST',
      data: formData,
      dataType: 'json',
      success: (data) => {
        completedCount++;
        if (data.status === 'success') {
          updateFileStatus(file.name, 'success');
        } else {
          updateFileStatus(file.name, 'error');
        }
        checkAllUploadsComplete();
      },
      error: (error) => {
        console.error('Upload error:', error);
        completedCount++;
        updateFileStatus(file.name, 'error');
        checkAllUploadsComplete();
      }
    });
  }

  function updateFileStatus(fileName, status) {
    const items = fileList.getElementsByClassName('file-item');
    for (let item of items) {
      if (item.firstElementChild.textContent === fileName) {
        let icon = '';
        if (status === 'success') {
          icon = '<i class="fas fa-check" style="color: green;"></i>';
        } else if (status === 'error') {
          icon = '<i class="fas fa-exclamation-triangle" style="color: red;"></i>';
        }
        item.lastElementChild.innerHTML = `${icon} ${status}`;
        break;
      }
    }
  }

  function checkAllUploadsComplete() {
    if (completedCount === uploadCount) {
      nextStepButton.disabled = false;
    }
  }

  // Add redirect to metadata screen on "Next Step" click
  nextStepButton.addEventListener('click', () => {
    window.location.href = `/symbolsets/${window.symbolsetSlug}/metadata`;
  });
});
