class ImportExternalSymbolSetsJob < ApplicationJob
  queue_as :default

  require 'open-uri'
  require 'zip'
  
  # All import methods should be idempotent.
  # That is, they should only create new records for symbolsets, symbols and labels if those records don't already exist.
  # No duplicates should be created.
  def perform(*args)
    # jellow
    # tawasol
    # bliss
    arasaac
  end
  
  def arasaac
    json_filename = 'tmp/import/MyMemory-2018.10.29-mini.json'
    images_path = 'tmp/import/'

    # Find or create the Symbolset
    symbolset = Symbolset.create_with(
        name: 'ARASAAC',
        publisher: 'Government of Aragon',
        publisher_url: 'http://www.arasaac.org/',
        licence: Licence.find_by(properties: 'by-sa')
    ).find_or_create_by!(slug: 'arasaac')

    invalid_symbols = []
    file = File.read(json_filename)
    symbols = JSON.parse(file, symbolize_names: true)
    
    symbols.each do |symbol|
      # Skip non-ARASAAC symbols
      next unless "ARASAAC Symbol Set".in?(symbol[:local_filename])
      
      publisher_ref = symbol[:local_filename].sub('.png', '').sub('ARASAAC Symbol Set\\', '')
      
      # Skip existing symbols
      next if Picto.find_by(publisher_ref: publisher_ref).present?
      
      begin
        file = File.open("#{images_path}#{symbol[:local_filename].gsub('\\','/')}")
        
        # Prepare the labels
        labels = []
        symbol[:descriptions].each do |label|
          # Begin/rescue to skip non-existent Languages
          # e.g. Brazilian Portuguese, which doesn't have an ISO 639 code
          begin
            labels << Label.new(
                language: Language.find_by!(iso639_1: label[0]),
                text: label[1]
            )
          rescue ActiveRecord::RecordNotFound
            puts "Skipping #{label[0]} for #{symbol[:id]}"
          end
          
        end
        
        # Try to create the Picto
        picto = symbolset.pictos.create_with(
            part_of_speech: :noun,
            images: [Image.new(imagefile: file)],
            labels: labels
        ).find_or_create_by!(
            publisher_ref: publisher_ref
        )
      rescue Errno::ENOENT => e
        # TODO: handle symbols with missing filenames
        invalid_symbols << {symbol: symbol, error: e}
      end
    end
    invalid_symbols
    invalid_symbols.count
  end
  
  def bliss
    csv_filename = 'tmp/bliss-import/import.google.csv'
    images_path = 'tmp/bliss-import/images/'

    language_map = {
        english:         Language.find_by(iso639_1: 'en'),
        swedish:         Language.find_by(iso639_1: 'sv'),
        norwegian:       Language.find_by(iso639_1: 'no'),
        finnish:         Language.find_by(iso639_1: 'fi'),
        hungarian:       Language.find_by(iso639_1: 'hu'),
        german:          Language.find_by(iso639_1: 'de'),
        dutch:           Language.find_by(iso639_1: 'nl'),
        afrikaans:       Language.find_by(iso639_1: 'af'),
        russian:         Language.find_by(iso639_1: 'ru'),
        latvian:         Language.find_by(iso639_1: 'lv'),
        polish:          Language.find_by(iso639_1: 'pl'),
        french:          Language.find_by(iso639_1: 'fr'),
        spanish:         Language.find_by(iso639_1: 'es'),
        portugese_draft: Language.find_by(iso639_1: 'pt'),
        italian_draft:   Language.find_by(iso639_1: 'it'),
        danish_draft:    Language.find_by(iso639_1: 'da')
    }

    # Find or create the Symbolset
    symbolset = Symbolset.create_with(
        name: 'Blissymbolics',
        publisher: 'Blissymbolics Communication International',
        publisher_url: 'http://www.blissymbolics.org/',
        licence: Licence.find_by(properties: 'by-sa')
    ).find_or_create_by!(slug: 'blissymbolics')

    invalid_symbols = []

    # Parse the CSV
    symbols = CSV.parse(open(csv_filename, "r:UTF-8"), { headers: true, header_converters: :symbol }).map(&:to_h)

    symbols.each do |symbol|
      next if symbol[:gs_do_not_import] == 1
      
      picto = symbolset.pictos.find_by(publisher_ref: symbol[:bciav])
      
      if picto.nil?
        begin
          file = File.open("#{images_path}#{symbol[:english]}.svg")
          
          labels = []
          # For each column of the symbol, check if the column represents a language, and prepare a label in that language
          symbol.each do |column|
            labels << Label.new(
              language: language_map[column[0]],
              # If the label is :english, we need to replace _underscores with spaces
              text: column[0] == :english ? column[1].gsub('_',' ') : column[1],
              # The description is only available in English, so we'll store it for English only
              description: (symbol[:derivation_explanation] if column[0] == :english)
            ) if column[0].in? language_map and column[1].present?
          end
          
          puts 'creating picto'
          # Try to create the Picto
          picto = symbolset.pictos.create_with(
              part_of_speech: symbol[:gs_pos],
              images: [Image.new(imagefile: file)],
              labels: labels
          ).find_or_create_by!(
              publisher_ref: symbol[:bciav]
          )
        
        rescue ArgumentError
          # TODO: handle symbols with wrong PoS-es
        rescue Errno::ENOENT => e
          # TODO: handle symbols with missing filenames
          invalid_symbols << {symbol: symbol, error: e}
        end
      end
    end
    invalid_symbols
  end
  
  # Use this query to produce a CSV file of *labels* in Tawasol.
  # This import must assume each row in the CSV is a new label, not a new symbol
  # SELECT s.*, le.language as le_language, le.pos AS le_pos, le.phonemes AS le_phonemes, le.label AS le_label, le.description AS le_description FROM symbolnet.symbol s
  # JOIN symbolnet.lexical_entry le ON s.lexical_entry_id = le.lexical_entry_id
  # WHERE s.source_id = 1;
  # Due to Tawasol's sameas table, the import has to be run once for Arabic languages, then again for English.
  def tawasol
    csv_filename = 'tmp/tawasol-import/tawasol-sameas-eng.csv'
    images_path = 'tmp/tawasol-import/images'
    
    language_map = {
        MSA:    Language.find_by(iso639_1: 'ar'),
        Qatari: Language.find_by(iso639_3: 'afb'),
        Eng:    Language.find_by(iso639_1: 'en')
    }
    
    # pos_map = {
    #     'question words',
    #     'determiners'
    # }

    # Find or create the Symbolset
    symbolset = Symbolset.create_with(
        name: 'Tawasol',
        publisher: 'Mada',
        publisher_url: 'http://tawasolsymbols.org',
        licence: Licence.find_by(properties: 'by-sa')
    ).find_or_create_by!(slug: 'tawasol')

    invalid_symbols = []

    # Parse the CSV
    labels = CSV.parse(open(csv_filename, "r:UTF-8"), { headers: true, header_converters: :symbol }).map(&:to_h)
    
    labels.each do |label|
      
      picto = symbolset.pictos.find_by(publisher_ref: label[:image_uri])
      
      # No picto found? Create it with the current label
      if picto.nil?
        begin
          file = File.open("#{images_path}#{label[:image_uri]}")
        
          # Try to create or find the symbol with just the first language label
          picto = symbolset.pictos.create_with(
            part_of_speech: label[:le_pos],
            images: [Image.new(imagefile: file)],
            labels: [Label.new(
              language: language_map[label[:le_language].to_sym],
              text: label[:undiac_description],
              text_diacritised: label[:le_label],
              description: label[:le_description]
            )],
          ).find_or_create_by!(
            publisher_ref: label[:image_uri]
          )
        rescue ArgumentError
          # TODO: handle symbols with wrong PoS-es
        rescue Errno::ENOENT => e
          # TODO: handle symbols with missing filenames
          invalid_symbols << {symbol: label, error: e}
        end
      #   Else, add the current label to the existing Picto
      else
        picto.labels.create_with(
            text: label[:le_label],
            # text_diacritised: label[:le_label],
            description: label[:le_description]
        ).find_or_create_by!(
            language: language_map[label[:le_language].to_sym]
        )
      end
    end

    invalid_symbols
  end
  
  def jellow
    csv_filename = 'tmp/jellow-import/jellow.csv'
    images_path = 'tmp/jellow-import/images/'
    
    # Find or create the Symbolset
    symbolset = Symbolset.create_with(
        name: 'Jellow',
        publisher: 'IDC School of Design',
        publisher_url: 'http://www.jellow.org',
        licence: Licence.find_by(properties: 'by-nc-sa')
    ).find_or_create_by!(slug: 'jellow')
    
    invalid_symbols = []
    
    # Parse the CSV
    symbols = CSV.parse(open(csv_filename, "r:UTF-8"), { headers: true, header_converters: :symbol }).map(&:to_h)

    symbols.each do |symbol|
      begin
        puts symbol[:id]
        raise if symbol[:id].nil?
        
        picto = symbolset.pictos.find_by(publisher_ref: symbol[:id])
        
        # Create the symbol if it doesn't already exist
        # NB: find_or_create_by handles this, but the Image.new process is slow
        if picto.nil?
          file = File.open("#{images_path}#{symbol[:id]}.svg")
          
          # Try to create or find the symbol with just an English label
          picto = symbolset.pictos.create_with(
            part_of_speech: 'noun',
            images: [Image.new(imagefile: file)],
            labels: [Label.new(
              language: Language.find_by(iso639_1: 'en'),
              text: symbol[:english].strip
            )],
          ).find_or_create_by!(
              publisher_ref: symbol[:id]
          )
        end
        
        # Try to add Hindi label if one is provided in the CSV
        picto.labels.create_with(
          text: symbol[:hindi].strip
        ).find_or_create_by!(
          language: Language.find_by(iso639_1: 'hi')
        ) unless symbol[:hindi].blank?
  
        # Try to add Marathi label if one is provided in the CSV
        picto.labels.create_with(
            text: symbol[:marathi].strip
        ).find_or_create_by!(
            language: Language.find_by(iso639_1: 'mr')
        ) unless symbol[:marathi].blank?
      end
    rescue ActiveRecord::RecordInvalid => e
      symbol[:error] = e.message
      invalid_symbols << symbol
    end
    invalid_symbols
  end
end
