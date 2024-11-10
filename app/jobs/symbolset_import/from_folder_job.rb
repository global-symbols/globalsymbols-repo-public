class SymbolsetImport::FromFolderJob < ApplicationJob
  queue_as :default

  # Recursively looks for SVG files in source_directory and adds them to symbolset,
  # using the filename (excluding .svg suffix) as the publisher_ref.
  # @param [string] source_directory Path to symbols.
  # @param [Symbolset] symbolset Target Symbolset to create new Pictos in.
  # @param [Language] language Language of Labels.
  # @param [Source] source Source of Pictos.
  # @param [boolean] append_to_symbolset When false, raises an exception if the Symbolset already contains Pictos.
  def perform(source_directory, symbolset, language, source, append_to_symbolset = false)

    source_directory = Pathname.new(source_directory)

    raise unless source_directory.directory? and language and symbolset and source

    # If there are any pictos already in the symbolset, raise an exception.
    raise if symbolset.pictos.count > 0 and !append_to_symbolset

    source_directory.glob('**/*.svg') do |file_path|

      file = Pathname.new(file_path)

      puts file.basename

      symbolset.pictos.create_with(
        source: source,
        part_of_speech: :noun,
        images: [Image.new(imagefile: file.open)],
        labels: [
                  Label.new(
                    language: language,
                    source: source,
                    text: file.basename.sub(/\.svg$/, '').to_s
                    )
                ]
      ).find_or_create_by(
        publisher_ref: file.basename.sub(/\.svg$/, '').to_s,
        symbolset_id: symbolset.id
      )
    end
  end
end
