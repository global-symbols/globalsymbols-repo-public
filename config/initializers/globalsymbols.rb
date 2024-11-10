NOUN_PROJECT_API_KEY    = '42ace7f81a8b42ca825903ef9bce0f7c'
NOUN_PROJECT_API_SECRET = '1e1e5a3ac5994541aa64d6d73c80b28a'

AZURE_TRANSLATOR_KEY = '8df45b468abb4edfb25f455ec56d5eb9'

PRAWN_SVG_ADDITIONAL_FONT_PATHS = [
  "/usr/share/fonts/msttcore"
]

PRAWN_SVG_ADDITIONAL_FONT_PATHS.each do |font_path|
  if File.directory?(font_path)
    Prawn::SVG::FontRegistry.font_path << font_path
  end
end
