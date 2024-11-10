class SymbolsetSync::OtsimoTurkishJob < ApplicationJob
  queue_as :default

  def perform(*args)

    result = {
      missing_files: [],
      unreferenced_images: [],
      invalid: [],
      added: 0,
      skipped: 0
    }

    source_directory = Rails.root.join('tmp/otsimo')

    # Find or create the Symbolset
    symbolset = Symbolset.create_with(
      name: 'Mulberry & Otsimo Turkish Symbol Set',
      publisher: 'Otsimo (Ersin Kiymaz, Naz Yilmaz, Ersin Sinay)',
      publisher_url: 'https://otsimo.com',
      licence: Licence.find_by(properties: 'by-sa')
    ).find_or_create_by!(slug: 'otsimo')

    # Stores the names of all symbol files in the CSV, so we can later check that all files were included in the CSV.
    symbol_filenames = []

    english = Language.find_by(iso639_1: :en)
    turkish = Language.find_by(iso639_1: :tr)

    source = Source.find_by!(slug: 'global-symbols')

    # symbols_url = 'https://github.com/straight-street/mulberry-symbols/raw/master/symbol-info.csv'
    symbols_url = "#{source_directory}/otsimo.csv"
    symbols = CSV.parse(open(symbols_url, "r:UTF-8"), { headers: true, header_converters: :symbol }).map(&:to_h)

    # Import Symbols
    symbols.each do |symbol|

      next if symbol[:symbol].nil?

      symbol_filenames << symbol[:symbol]

      picto = symbolset.pictos.find_by(publisher_ref: symbol[:symbol])

      # If no Picto was found, we need to import it
      if picto.nil?

        case symbol[:part_of_speech].downcase
        when 'letter'
          pos = 'noun'
        when 'verbcomplex'
          pos = 'verb'
        when 'phrase'
          pos = 'noun'
        else
          pos = symbol[:part_of_speech].downcase
        end

        image_filename = Rails.root.join("tmp/otsimo/#{symbol[:symbol]}.svg")

        begin
          imagestream = File.open(image_filename)
        rescue Errno::ENOENT
          # If no SVG was found, add this symbol to the list of missing_files
          result[:missing_files] << symbol[:symbol]
          next
        end

        file = File.open(image_filename)

        labels = []
        labels << Label.new(language: english, source: source, text: symbol[:label_en]) if symbol[:label_en]
        labels << Label.new(language: turkish, source: source, text: symbol[:label_tr]) if symbol[:label_tr]

        begin
          picto = symbolset.pictos.create_with(
            part_of_speech: pos,
            source: source,
            images: [Image.new(imagefile: file)],
            labels: labels
          ).find_or_create_by!(
            symbolset_id: symbolset.id,
            publisher_ref: symbol[:symbol]
          )

          result[:added] += 1

        rescue ActiveRecord::RecordInvalid => e
          puts "Error processing #{symbol[:symbol]}"
          pp e
          result[:skipped] += 1
          result[:invalid] << {
            picto: picto,
            symbol: symbol,
            error: e
          }
        end

      end
    end

    # Check for SVG files that weren't in the CSV file
    svg_files = Dir.glob("**/*.svg", base: source_directory)

    svg_files.each do |filename|
      result[:unreferenced_images] << filename unless symbol_filenames.include? filename.delete_suffix('.svg')
    end

    result
  end
end
