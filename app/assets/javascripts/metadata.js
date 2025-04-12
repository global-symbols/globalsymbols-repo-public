function initializeMetadata() {
  const toggleCheckbox = document.getElementById('toggle-image-background');
  const posApplyButton = document.querySelector('.pos-apply-button');
  const langApplyButton = document.querySelector('.lang-apply-button');
  const filenameApplyButton = document.querySelector('.filename-apply-button');
  const rows = document.querySelectorAll('.spreadsheet-table tbody tr');
  const finishButton = document.getElementById('finish');

  if (!toggleCheckbox || !finishButton) {
    return;
  }

  // Replace optional chaining with explicit if checks
  toggleCheckbox.replaceWith(toggleCheckbox.cloneNode(true));
  if (posApplyButton) posApplyButton.replaceWith(posApplyButton.cloneNode(true));
  if (langApplyButton) langApplyButton.replaceWith(langApplyButton.cloneNode(true));
  if (filenameApplyButton) filenameApplyButton.replaceWith(filenameApplyButton.cloneNode(true));
  finishButton.replaceWith(finishButton.cloneNode(true));

  const newToggleCheckbox = document.getElementById('toggle-image-background');
  const newPosApplyButton = document.querySelector('.pos-apply-button');
  const newLangApplyButton = document.querySelector('.lang-apply-button');
  const newFilenameApplyButton = document.querySelector('.filename-apply-button');

  function setBackground(row) {
    const imageCell = row.querySelector('.image');
    const image = imageCell.querySelector('img');
    const checkbox = row.querySelector('input[type="checkbox"]');

    if (!image || !checkbox) return;

    if (checkbox.checked) {
      imageCell.classList.add('white-background');
      image.classList.add('white-background');
    } else {
      imageCell.classList.remove('white-background');
      image.classList.remove('white-background');
    }
  }

  newToggleCheckbox.addEventListener('change', () => {
    rows.forEach(row => {
      const checkbox = row.querySelector('input[type="checkbox"]');
      if (checkbox) {
        checkbox.checked = newToggleCheckbox.checked;
        setBackground(row);
      }
    });
  });

  rows.forEach(row => {
    const checkbox = row.querySelector('input[type="checkbox"]');
    if (checkbox) {
      checkbox.addEventListener('change', () => setBackground(row));
      setBackground(row);
    }
  });

  if (newPosApplyButton) {
    newPosApplyButton.addEventListener('click', () => {
      const pos = document.getElementById('bulk-part-of-speech').value;
      if (pos) {
        rows.forEach(row => {
          const posInput = row.querySelector('input[name="pictos[][part_of_speech]"]');
          if (posInput) posInput.value = pos;
        });
      }
    });
  }

  if (newLangApplyButton) {
    newLangApplyButton.addEventListener('click', () => {
      const lang = document.getElementById('bulk-language').value;
      if (lang) {
        rows.forEach(row => {
          const langInput = row.querySelector('input[name="pictos[][language_id]"]');
          if (langInput) langInput.value = lang;
        });
      }
    });
  }

  if (newFilenameApplyButton) {
    newFilenameApplyButton.addEventListener('click', () => {
      rows.forEach(row => {
        const filename = row.querySelector('.filename').textContent.trim();
        const label = row.querySelector('input[name="pictos[][text]"]');
        if (label) label.value = filename;
      });
    });
  }
}

document.addEventListener('DOMContentLoaded', initializeMetadata);
document.addEventListener('turbolinks:load', initializeMetadata);
