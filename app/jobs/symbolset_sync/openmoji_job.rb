module SymbolsetSync
  class OpenmojiJob < ApplicationJob
    queue_as :default

    require 'zip'
    require 'timeout'

    def perform(version = '12.3.0', path = 'https://github.com/hfg-gmuend/openmoji/archive/12.3.0.zip')
      
      # The following symbols cause an infinite loop when converting in Imagemagick 6.9.11-21 on Mac
      symbols_failing_in_imagemagick = [
          '1F4AF',
          '1F90F',
          '1F448',
          '1F449',
          '270A',
          '1F44A',
          '1F64C',
          '1F911',
          '1F92B',
          '1F910',
          '1F62C'
      ]
      
      failed_symbols = []
  
      symbolset = Symbolset.create_with(
          name: 'OpenMoji',
          publisher: 'OpenMoji Project',
          publisher_url: 'https://openmoji.org',
          licence: Licence.find_by!(version: '4.0', properties: 'by-sa'),
          auto_update: true
      ).find_or_create_by!(slug: 'openmoji')

      # The data source is a repo of the symbols
      source = Source.find_by!(slug: 'repo')
      
      # symbolset = symbolset.include(:pictos)
  
      english = Language.find_by!(iso639_3: :eng)

      # If this Symbolset is not meant to receive updates, stop now.
      return unless symbolset.auto_update

      p "Downloading and opening OpenMoji #{version} (about 100MB when last checked)."

      file = open(path)
      
      # Open the zip file
      Zip::File.open_buffer(file) do |zip|
  
        p 'Done'

        json = zip.read("openmoji-#{version}/data/openmoji.json")
        
        symbols = JSON.parse(json)
        
        p "Found #{symbols.count} symbols"

        symbols.each do |symbol|
          # pp symbol
          
          # If we are in dev, skip symbols that fail on the Mac.
          # e.g. if '1F90F' is in symbols_failing_in_imagemagick, skip a symbol with hexcode '1F90F-1F3FB' or '1F90F'
          if (Rails.env.development? or Rails.env.test?) and symbol['hexcode'].split('-').any? { |hexcode| symbols_failing_in_imagemagick.include? hexcode }
            p "Skipping #{symbol['hexcode']} because it will infinite-loop Imagemagick."
            next
          end
          
          # Skip if the symbol already exists in the DB.
          if symbolset.pictos.find_by(publisher_ref: symbol['hexcode']).present?
            p "Skipping #{symbol['hexcode']} because it already exists"
            next
          end
          
          p "Adding #{symbol['hexcode']}"
          
          svg_body = zip.read("openmoji-#{version}/color/svg/#{symbol['hexcode']}.svg")

          # Inject hair and skin element classes
          # svg_body = inject_aac_classes(svg_body)

          # Prepare a StringIO of the SVG file body, to avoid extracting the file to disk.
          # This will be used by the Carrierwave uploader.
          svg_stringio = StringIO.new(svg_body)
          # We have to fool Carrierwave by providing a filename in the StringIO.
          def svg_stringio.original_filename; 'temp.svg'; end
          
          # p 'Preparing Labels'
          
          # Use the Annotation as a Label
          labels = [Label.new(
            source:    source,
            pulled_at: DateTime.now,
            language: english,
            text: symbol['annotation'].titleize
          )]

          symbol['openmoji_tags'].split(',').map{|t| t.strip}.select{|t| !t.blank?}.each do |tag|
            labels << Label.new(
              source:    source,
              pulled_at: DateTime.now,
              language: english,
              text: tag.titleize
            )
          end

          # p 'Prepared Labels'

          picto = symbolset.pictos.create_with!(
              part_of_speech: :noun,
              visibility: :everybody,
              # description: "",
              images: [Image.new(imagefile: svg_stringio)],
              labels: labels,
              source:    source,
              pulled_at: DateTime.now
          ).find_or_create_by!(
              symbolset_id: symbolset.id,
              publisher_ref: symbol['hexcode']
          )
        end
      end

      p "Import finished. There were #{failed_symbols.length} failures:"
      pp failed_symbols
      failed_symbols
      
    end

    def inject_aac_classes(svg_body)
      svg_body.gsub!('id="hair"', 'id="hair" class="aac-hair-fill"')
      svg_body.gsub!('id="skin"', 'id="skin" class="aac-skin-fill"')
    end
    
  end
end
