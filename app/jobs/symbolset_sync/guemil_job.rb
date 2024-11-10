module SymbolsetSync
  class GuemilJob < ApplicationJob
    queue_as :default
  
    
    
    # Collects Guemil icons from a zip file and loads them as Pictos.
    # To prepare the zip file, download the current Guemil icons and create a zip of just the SVG files.
    # Due to messy structuring and versioning of the Guemil repo at Github, this cannot be scheduled.
    # Filenames include the English label and an ID number. No translations are offered.
    #
    # To hedge against further versioning crimes by Guemil Project, we are saving the full filename as the publisher_id.
    #
    # See https://github.com/Guemil/Guemil_Icons
    #
    # Download v15 icons at
    # https://github.com/Guemil/Guemil_Icons/tree/master/01_Guemil_Icons_v15%20(2020)/Guemil_Icons_v15_svg_2020
    #
    # @param [string] path  Full path to a zip file containing only the Guemil SVG files. Flat, with no directories.
    def perform(path)
  
      symbolset = Symbolset.create_with(
          name: 'Guemil',
          publisher: 'Guemil Project',
          publisher_url: 'http://www.guemil.info',
          licence: Licence.find_by!(version: '4.0', properties: 'by-nc-sa')
      ).find_or_create_by!(slug: 'guemil')

      # The data source is a repo of the symbols
      source = Source.find_by!(slug: 'repo')
      
      english = Language.find_by!(iso639_3: :eng)

      Zip::File.open_buffer(open(path)) do |zip|
        zip.glob("*.svg").each do |svg_file|
          svg_body = svg_file.get_input_stream.read

          # Prepare a StringIO of the SVG file body, to avoid extracting the file to disk.
          # This will be used by the Carrierwave uploader.
          svg_stringio = StringIO.new(svg_body)
          # We have to fool Carrierwave by providing a filename in the StringIO.
          def svg_stringio.original_filename; 'temp.svg'; end

          match = File.basename(svg_file.name, '.*').match /(?<id>\d+)_(?<label>.+)_v15/

          picto = symbolset.pictos.create_with!(
              part_of_speech: :noun,
              visibility: :everybody,
              # description: "",
              images: [Image.new(imagefile: svg_stringio)],
              labels: [Label.new(
                  text: match['label'].gsub('_', ' '),
                  language: english,
                  source:   source
              )],
              pulled_at: DateTime.now,
              source:   source
          ).find_or_create_by!(
              symbolset_id: symbolset.id,
              publisher_ref: File.basename(svg_file.name, '.*')
          )
          
        end
      end
      
    end
  end
end
