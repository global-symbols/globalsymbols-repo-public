class ActivateLanguagesJob < ApplicationJob
  queue_as :default

  # Activates a set of default languages for dropdowns, etc.
  def perform(*args)

    language_names = [
      "Albanian",
      "Arabic",
      "Armenian",
      "Bulgarian",
      "Catalan",
      "Chinese",
      "Croatian",
      "Danish",
      "Dutch",
      "English",
      "French",
      "German",
      "Hindi",
      "Italian",
      "Macedonian",
      "Marathi",
      "Modern Greek (1453-)",
      "Montenegrin",
      "Portuguese",
      "Romanian",
      "Russian",
      "Serbian",
      "Serbo-Croatian",
      "Spanish",
      "Turkish"
    ]

    unsupported_at_azure = [
      "Serbo-Croatian"
    ]

    language_names.each do |language_name|
      Language.unscoped.find_by!(name: language_name).update({
        active: true,
        azure_translate_supported: unsupported_at_azure.include?(language_name) ? false : true
      })
    end

  end
end
