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

  const newToggleCheckbox = document.getElementById('toggle-image-background');
  const newPosApplyButton = document.querySelector('.pos-apply-button');
  const newLangApplyButton = document.querySelector('.lang-apply-button');
  const newFilenameApplyButton = document.querySelector('.filename-apply-button');

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
      // Basic formatting logic (remove extension, replace underscores/hyphens, lowercase all, remove brackets)
      if (filenameDropdown.value === 'basic_formatting') {
        rows.forEach(row => {
          const filenameCell = row.querySelector('td:nth-child(2)');
          const labelInput = row.querySelector('td:nth-child(4) input');
          if (filenameCell && labelInput) {
            let filename = filenameCell.textContent.trim();
            if (filename && filename !== 'N/A') {
              filename = filename.replace(/\.[^/.]+$/, '').replace(/[_-]/g, ' '); // Remove extension, replace underscores/hyphens
              filename = filename.replace(/\([^()]*\)/g, ''); // Remove brackets and their contents
              filename = filename.replace(/\s+/g, ' ').trim(); // Clean up extra spaces
              filename = filename.toLowerCase(); // Lowercase all letters
              labelInput.value = filename;
            }
          }
        });
      }
      // Basic formatting + remove numbers and brackets
      else if (filenameDropdown.value === 'basic_and_remove_numbers') {
        rows.forEach(row => {
          const filenameCell = row.querySelector('td:nth-child(2)');
          const labelInput = row.querySelector('td:nth-child(4) input');
          if (filenameCell && labelInput) {
            let filename = filenameCell.textContent.trim();
            if (filename && filename !== 'N/A') {
              // Apply basic formatting
              filename = filename.replace(/\.[^/.]+$/, '').replace(/[_-]/g, ' '); // Remove extension, replace underscores/hyphens
              filename = filename.replace(/\([^()]*\)/g, ''); // Remove brackets and their contents
              filename = filename.replace(/\s+/g, ' ').trim(); // Clean up extra spaces
              filename = filename.toLowerCase(); // Lowercase all letters
              // Remove numbers
              filename = filename.replace(/\d+/g, '');
              // Clean up extra spaces that might result from removing numbers
              filename = filename.replace(/\s+/g, ' ').trim();
              labelInput.value = filename;
            }
          }
        });
      }
      // Basic formatting + remove numbers and brackets, keep capitalization
      else if (filenameDropdown.value === 'basic_and_remove_numbers_capitalised') {
        rows.forEach(row => {
          const filenameCell = row.querySelector('td:nth-child(2)');
          const labelInput = row.querySelector('td:nth-child(4) input');
          if (filenameCell && labelInput) {
            let filename = filenameCell.textContent.trim();
            if (filename && filename !== 'N/A') {
              // Apply basic formatting
              filename = filename.replace(/\.[^/.]+$/, '').replace(/[_-]/g, ' '); // Remove extension, replace underscores/hyphens
              filename = filename.replace(/\([^()]*\)/g, ''); // Remove brackets and their contents
              filename = filename.replace(/\s+/g, ' ').trim(); // Clean up extra spaces
              // Remove numbers
              filename = filename.replace(/\d+/g, '');
              // Clean up extra spaces that might result from removing numbers
              filename = filename.replace(/\s+/g, ' ').trim();
              labelInput.value = filename;
            }
          }
        });
      }
    });
  }
}

document.addEventListener('DOMContentLoaded', initializeMetadata);
document.addEventListener('turbolinks:load', initializeMetadata);