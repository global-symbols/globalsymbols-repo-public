// app/assets/javascripts/metadata.js
function initializeMetadata() {
  const toggleCheckbox = document.getElementById('toggle-image-background');
  const imageColumns = document.querySelectorAll('.image-column');
  const posDropdown = document.querySelector('.pos-dropdown');
  const posApplyButton = document.querySelector('.pos-apply-button');
  const posSelects = document.querySelectorAll('select[name^="part_of_speech"]');
  const langDropdown = document.querySelector('.lang-dropdown');
  const langApplyButton = document.querySelector('.lang-apply-button');
  const langSelects = document.querySelectorAll('select[name^="language_ids"]');
  const filenameDropdown = document.querySelector('.filename-dropdown');
  const filenameApplyButton = document.querySelector('.filename-apply-button');
  const rows = document.querySelectorAll('.spreadsheet-table tbody tr');
  const finishButton = document.getElementById('finish');

  if (!toggleCheckbox || !finishButton) {
    return;
  }

  toggleCheckbox.replaceWith(toggleCheckbox.cloneNode(true));
  posApplyButton?.replaceWith(posApplyButton?.cloneNode(true));
  langApplyButton?.replaceWith(langApplyButton?.cloneNode(true));
  filenameApplyButton?.replaceWith(filenameApplyButton?.cloneNode(true));
  finishButton.replaceWith(finishButton.cloneNode(true));

  const newToggleCheckbox = document.getElementById('toggle-image-background');
  const newPosApplyButton = document.querySelector('.pos-apply-button');
  const newLangApplyButton = document.querySelector('.lang-apply-button');
  const newFilenameApplyButton = document.querySelector('.filename-apply-button');
  const newFinishButton = document.getElementById('finish');

  newToggleCheckbox.addEventListener('change', () => {
    imageColumns.forEach(cell => {
      cell.classList.toggle('black-background', newToggleCheckbox.checked);
    });
  });

  if (posDropdown && newPosApplyButton && posSelects.length > 0) {
    newPosApplyButton.addEventListener('click', () => {
      const selectedPos = posDropdown.value;
      if (selectedPos) posSelects.forEach(select => select.value = selectedPos);
    });
  }

  if (langDropdown && newLangApplyButton && langSelects.length > 0) {
    newLangApplyButton.addEventListener('click', () => {
      const selectedLang = langDropdown.value;
      if (selectedLang) langSelects.forEach(select => select.value = selectedLang);
    });
  }

  if (filenameDropdown && newFilenameApplyButton && rows.length > 0) {
    newFilenameApplyButton.addEventListener('click', () => {
      const selectedAction = filenameDropdown.value;
      rows.forEach(row => {
        const filenameCell = row.querySelector('td:nth-child(2)');
        const labelInput = row.querySelector('td:nth-child(4) input');
        if (filenameCell && labelInput) {
          let filename = filenameCell.textContent.trim();
          if (filename && filename !== 'N/A') {
            // Basic formatting: remove extension, replace _/- with spaces, remove brackets, capitalize first letter
            filename = filename.replace(/\.[^/.]+$/, '') // Remove extension
                              .replace(/[_-]/g, ' ')     // Replace _ or - with space
                              .replace(/[()]/g, '')      // Remove brackets ()
                              .trim();                   // Remove extra spaces
            filename = filename.charAt(0).toUpperCase() + filename.slice(1).toLowerCase();

            if (selectedAction === 'basic_remove_numbers') {
              // Additional step: remove all numbers
              filename = filename.replace(/\d/g, '').trim();
            }

            if (selectedAction === 'basic_formatting' || selectedAction === 'basic_remove_numbers') {
              labelInput.value = filename;
            }
          }
        }
      });
    });
  }

  newFinishButton.addEventListener('click', () => {
    window.location.href = `/symbolsets/${window.symbolsetSlug}`;
  });
}

document.addEventListener('DOMContentLoaded', initializeMetadata);
document.addEventListener('turbolinks:load', initializeMetadata);
