module SymbolsetSync
  class OchaJob < ApplicationJob
    queue_as :default
    
    require 'zip'
  
    def perform(url = 'https://www.dropbox.com/sh/tez260wz22f7q85/AAD1n38kh8SRQmh9qB8AUZkKa?dl=1')
      
      symbolset = Symbolset.create_with(
          name: 'OCHA Humanitarian Icons',
          publisher: 'OCHA Visual',
          publisher_url: 'https://www.unocha.org/',
          licence: Licence.find_by!(name: 'Public Domain'),
          auto_update: true
      ).find_or_create_by!(slug: 'ocha-humanitarian-icons')

      # The data source is a repo of the symbols
      source = Source.find_by!(slug: 'repo')
      
      english = Language.find_by!(iso639_3: :eng)
      
      # If this Symbolset is not meant to receive updates, stop now.
      return unless symbolset.auto_update
      
      # p 'Existing OCHA symbols:'
      # pp symbolset.pictos.pluck :publisher_ref
      
      p 'Downloading and opening OCHA.'
      
      # Open the zip file
      Zip::File.open(open(url)) do |zip|
        
        p 'Done'
        
        # Search for and iterate all SVG files in the zip
        zip.glob("**/*.svg").each do |svg_entry|
          
          svg_body = svg_entry.get_input_stream.read
          
          # If the current file looks like an SVG, and is not the SVG font file...
          if svg_body.include? '<svg ' and !svg_body.include? '<font '

            # Prepare a StringIO of the SVG file body, to avoid extracting the file to disk.
            # This will be used by the Carrierwave uploader.
            svg_stringio = StringIO.new(svg_body)
            # We have to fool Carrierwave by providing a filename in the StringIO.
            def svg_stringio.original_filename; 'ocha-temp.svg'; end
            
            extant_picto = symbolset.pictos.find_by(publisher_ref: File.basename(svg_entry.name, '.*'))

            # If a Picto already exists with the same publisher_ref...
            if extant_picto.present?

              # If the Image data has changed, update the Image
              if extant_picto.images.first.imagefile.read != svg_body
                extant_picto.images.first.update(imagefile: svg_stringio)
              end
              
            else
              # Otherwise, try to create the Picto
              
              picto = symbolset.pictos.create_with!(
                  part_of_speech: :noun,
                  visibility: :everybody,
                  # description: "",
                  images: [Image.new(imagefile: svg_stringio)],
                  labels: [Label.new(
                      language: english,
                      source:    source,
                      pulled_at: DateTime.now,
                      text: File.basename(svg_entry.name, '.*').gsub('-', ' ')
                  )],
                  pulled_at: DateTime.now,
                  source:    source
              ).find_or_create_by!(
                  symbolset_id: symbolset.id,
                  publisher_ref: File.basename(svg_entry.name, '.*')
              )
            end
          end
        end
      end
    end
  end
end
