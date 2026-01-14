# This is a manifest file that'll be compiled into application.js, which will include all the files
# listed below.
#
# Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
# vendor/assets/javascripts directory can be referenced here using a relative path.
#
# It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
# compiled file. JavaScript code in this file should be added after the last require_* statement.
#
# Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
# about supported directives.
#
# require jquery3
#= require rails-ujs
#= require activestorage
#= require turbolinks
#= require popper

# Load only required Bootstrap components
#= require bootstrap/util
#= require bootstrap/collapse
#= require bootstrap/dropdown
#= require bootstrap/tab
#= require bootstrap/tooltip
#= require bootstrap/modal

#= require clipboard

# Sorts tables in Surveys
#= require bootstrap-sortable
#= require_tree .


$(document).on "turbolinks:load", ->
  # Bootstrap file input fields: changes the label in the input to the filename, on change
  $('.custom-file-input').on 'change', ->
    fileName = $(this).val().split('\\').pop()
    $(this).siblings('.custom-file-label').addClass('selected').html fileName

  # Shows/hides label diacritised text field depending on language
  $('.gs-language-picker').on 'change', ->
    input = $(this).closest('form').find("input[name*='diacritised']")
    section = input.closest('.form-group')

    section.removeClass('d-none')

    if($(this).find('option:selected').text().toLowerCase().includes('arabic'))
      section.show()
    else
      section.hide()
      input.val('')

  # Trigger a change when the form loads so that the field is automatically shown/hidden as appropriate
  $('.gs-language-picker').trigger('change')

  # Enable the tooltip on 'Copy to Clipboard' buttons
  $('.clipboard-btn').tooltip()

  # Enable tooltips.
  $('[data-toggle="tooltip"]').tooltip();

  # Sets the tooltip on target to title, then sets it back to the original tooltip text
  flashTooltip = (target, title) ->
    original_title = $(target).attr('data-original-title')
    $(target).attr('title', title).tooltip('_fixTitle').tooltip('show').attr('title', original_title).tooltip '_fixTitle'

  # Activates 'Copy to Clipboard' buttons
  clipboard = new Clipboard('.clipboard-btn')
    .on 'success', (e) ->
      flashTooltip(e.trigger, 'Copied!')
      window.getSelection().removeAllRanges() # Clear the selection from the page
    .on 'error', (e) ->
      flashTooltip(e.trigger, 'Failed!')

  # When the locale selector is changed, alter the locale URL property.
  $('#select_locale').on 'change', (e) ->
    url = new URL(window.location)
    params = new URLSearchParams(url.search)
    params.set('locale', this.value)
    url.search = params.toString()

    window.location = url