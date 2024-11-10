
# Set languages that are enabled for i18n translation of the site.
I18n.available_locales = [:en, :bg, :ca, :de, :el, :es, :fr, :hr, :hy, :it, :mk, :nl, :ps, :ro, :sq, :sr_Cyrl, :sr_Latn, :tr, :uk, :ur]

Rails.application.configure do
  
  config.i18n.default_locale = :en
  
  # Allow translations to fall back to the default language, English.
  # This can alternatively be set per-environment.
  config.i18n.fallbacks = true
end