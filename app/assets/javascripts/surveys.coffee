$(document).on 'turbolinks:load', ->

  # Binds to the language selector on the Survey#print form.
  # Shows/hides labels for specific languages on printed Survey forms.
  $('#survey_print_language_selector').change ->

    # If no choice is made, then show all languages.
    if $(this).val() is ''
      $('.survey-label').show();

    # If a choice is made, hide everything and then show the requested language.
    # Shows the selected language by looking for the iso639_3 ID (e.g. survey-label-eng)
    else
      $('.survey-label').hide();
      $('.survey-label-' + $(this).val()).show();