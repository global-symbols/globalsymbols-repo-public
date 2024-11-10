module SymbolsetImport
  class ScleraJob < ApplicationJob
    queue_as :default
    
    # Imports Sclera Symbols.
    # Requires a JSON file, being the MyMemory.json dump from Pictoselector. See test fixtures for schema.
    # Requires a directory of png files.

    # BEWARE some filenames have special characters (e.g. "aërosol apparaat.png").
    # Ensure the files are provided in a way that preserves these names.
    # Zip files will flatten ü to u. BZ2 will preserve special characters.
    
    # @param [Array] symbols            Array of Symbols to add, parsed from the MyMemory.json file with something like
    #                                   JSON.parse(File.read(Rails.root.join('sclera.json')))
    # @param [String] images_directory  Path to a directory containing the PNG files, relative to Rails.root
    def perform(symbols, images_directory = 'tmp/import-sclera/sclera-dump-from-pictoselector')
      
      # Find or create the Sclera symbol set
      symbolset = Symbolset.create_with(
          name: 'Sclera Symbols',
          publisher: 'Sclera NPO',
          publisher_url: 'https://sclera.be',
          licence: Licence.find_by!(version: '4.0', properties: 'by-nc')
      ).find_or_create_by!(slug: 'sclera')

      # The data source is a repo of the symbols
      source = Source.find_by!(slug: 'repo')
      
      p "Starting with #{symbols.length} symbols"
      
      # The JSON contains ALL Pictoselector symbols, so we need to filter out non-Sclera ones.
      symbols = symbols.select { |symbol| symbol['local_filename'].starts_with? 'tijd\\' or !symbol['local_filename'].include? '\\' }

      p "Filtered down to #{symbols.length} symbols"
      
      # Prepare a list of Languages used in the JSON
      languages_list =  []
      symbols.each do |symbol|
        symbol['descriptions'].each do |description|
          # ...except Brazilian Portuguese, which has no ISO code.
          languages_list |= [description[0]] unless description[0] == :pt_BR
        end
      end
      
      # Grab each of these languages (faster than querying each time)
      languages = {}
      Language.where(iso639_1: languages_list).each do |l|
        languages[l.iso639_1] = l
      end
      
      # Build and insert the Pictos
      symbols.each do |symbol|
        
        labels = []

        # Build a list of Labels for the Picto
        symbol['descriptions'].each do |descriptions|
          
          language_code = descriptions[0]
          
          # We can't add Brazilian Portuguese Labels because the language has no ISO code.
          next if language_code == 'pt_BR'
          
          # Strip whitespace from the description text.
          descriptions[1].strip!
          # Skip if there is no text in the description
          next if descriptions[1].blank?
          
          # Split descriptions that contain multiple labels, strip whitespace from the result, and remove empty strings
          # e.g. "Kuchen, Torte , Schokoladenkuchen" or "do the dishes / washing up"
          texts = descriptions[1].split(/[,\/]/).map{ |text| text.strip }.select{ |text| !text.blank? }
          
          # Add a Label for each description
          texts.each do |text|

            text = text.titleize unless language_code == 'ar'
  
            labels << Label.new(
                language:  languages[language_code],
                text:      text,
                source:    source,
                pulled_at: DateTime.now
            )
          end
        end

        # pp labels
        
        # Open the image file. Substitute Windows backslashes in the path for unix backslashes.
        file = File.open(Rails.root.join(images_directory, symbol['local_filename'].gsub('\\', '/')))
        
        # Try to create the Picto.
        picto = symbolset.pictos.create_with!(
            part_of_speech: :noun,
            visibility: :everybody,
            images: [Image.new(imagefile: file)],
            labels: labels,
            source:   source,
            pulled_at: DateTime.now
        ).find_or_create_by!(
            symbolset_id: symbolset.id,
            publisher_ref: { pictoselector_id: symbol['id'], filename: File.basename(symbol['local_filename'], '.*')}.to_json
        )
      end
    end
  end
end
