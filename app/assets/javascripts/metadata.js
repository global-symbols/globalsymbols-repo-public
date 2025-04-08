// app/assets/javascripts/metadata.js
document.addEventListener('DOMContentLoaded', () => {
  if (window.metadataInitialized) return;
  window.metadataInitialized = true;

  // Toggle the background color of the Image column
  const toggleCheckbox = document.getElementById('toggle-image-background');
  const imageColumns = document.querySelectorAll('.image-column');

  if (toggleCheckbox) {
    toggleCheckbox.addEventListener('change', () => {
      imageColumns.forEach(cell => {
        if (toggleCheckbox.checked) {
          cell.classList.add('black-background');
        } else {
          cell.classList.remove('black-background');
        }
      });
    });
  }

  // Apply selected part of speech to all rows on button click
  const posDropdown = document.querySelector('.pos-dropdown');
  const posApplyButton = document.querySelector('.pos-apply-button');
  const posSelects = document.querySelectorAll('select[name^="part_of_speech"]');

  if (posDropdown && posApplyButton && posSelects.length > 0) {
    posApplyButton.addEventListener('click', () => {
      const selectedPos = posDropdown.value;
      if (selectedPos) {
        posSelects.forEach(select => {
          select.value = selectedPos;
        });
      }
    });
  }

  // Apply selected language to all rows on button click
  const langDropdown = document.querySelector('.lang-dropdown');
  const langApplyButton = document.querySelector('.lang-apply-button');
  const langSelects = document.querySelectorAll('select[name^="language_ids"]');

  if (langDropdown && langApplyButton && langSelects.length > 0) {
    langApplyButton.addEventListener('click', () => {
      const selectedLang = langDropdown.value;
      if (selectedLang) {
        langSelects.forEach(select => {
          select.value = selectedLang;
        });
      }
    });
  }

  // Apply filename action to move formatted filename to label field on button click
  const filenameDropdown = document.querySelector('.filename-dropdown');
  const filenameApplyButton = document.querySelector('.filename-apply-button');
  const rows = document.querySelectorAll('.spreadsheet-table tbody tr');

  if (filenameDropdown && filenameApplyButton && rows.length > 0) {
    filenameApplyButton.addEventListener('click', () => {
      const selectedAction = filenameDropdown.value;
      if (selectedAction === 'basic_formatting') {
        rows.forEach(row => {
          const filenameCell = row.querySelector('td:nth-child(2)'); // Original Filename column
          const labelInput = row.querySelector('td:nth-child(4) input'); // Label column input

          if (filenameCell && labelInput) {
            let filename = filenameCell.textContent.trim();
            if (filename && filename !== 'N/A') {
              // Remove file extension (e.g., .txt, .jpg)
              filename = filename.replace(/\.[^/.]+$/, '');
              // Remove underscores and hyphens
              filename = filename.replace(/[_-]/g, ' ');
              // Capitalize the first word
              filename = filename.charAt(0).toUpperCase() + filename.slice(1).toLowerCase();
              // Move the formatted filename to the label input
              labelInput.value = filename;
            }
          }
        });
      }
      // Add more actions here later
    });
  }

  // Existing JavaScript for the Finish button
  const finishButton = document.getElementById('finish');
  if (finishButton) {
    finishButton.addEventListener('click', () => {
      window.location.href = `/symbolsets/${window.symbolsetSlug}`;
    });
  }
});
