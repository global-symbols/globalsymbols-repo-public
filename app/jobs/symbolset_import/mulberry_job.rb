class SymbolsetImport::MulberryJob < ApplicationJob
  queue_as :default

  def perform(github_tag)
    zip_url = "https://github.com/mulberrysymbols/mulberry-symbols/releases/download/#{github_tag}/mulberry-symbols.zip"
    zip_filename = "gs-import-symbolset-straight_street-#{SecureRandom.uuid}.zip"
    zip_filepath = Rails.root.join('tmp', zip_filename)

    csv_url = "https://github.com/mulberrysymbols/mulberry-symbols/releases/download/#{github_tag}/symbol-info.csv"

    wrong_filename_mappings = {
      blender_drinks: 'blender-drinks',
      tv_change_channel: 'change_tv_channel_,_to',
      football_dribble: 'dribble_football_,_to',
      features: 'features_facial',
      'open_computer_folder_,_to': 'computer_folder_open_,_to',
      score_goal: 'score_goal_,_to',
      'send_email_,_to': 'email_send_,_to',
      'sit_at_computer_2_,_to': 'sit_at_computer_,_to_2',
      'television_switch_on': 'switch_on_television_,_to',
      'light_switch_turn_off': 'turn_off_light_switch_,_to'
    }

    missing_files = []

    uuid = SecureRandom.uuid

    begin
      # Find or create the Symbolset
      symbolset = Symbolset.create_with(
        name: 'Mulberry Symbols',
        publisher: 'Steve Lee',
        publisher_url: 'https://mulberrysymbols.org/',
        licence: Licence.find_by(properties: 'by-sa')
      ).find_or_create_by!(
        slug: 'mulberry'
      )

      english = Language.find_by(iso639_1: :en)
      source = Source.find_by(slug: :repo)

      # Try to get the CSV file
      symbols = CSV.parse(open(csv_url, "r:UTF-8"), { headers: true, header_converters: :symbol }).map(&:to_h)

      p 'Downloaded CSV.'

      # Zip::InputStream.open(open(zip_url)) do |zip|
      # Zip::File.open(Rails.root.join('tmp', 'mulberry-symbols-master.zip')) do |zip|
      Zip::File.open(open(zip_url)) do |zip|

        # Import Symbols
        symbols.each do |symbol|

          next if symbol[:symbol].nil?

          picto = symbolset.pictos.find_by(publisher_ref: symbol[:symbol])

          # If no Picto was found, we need to import it
          if picto.nil?

            symbol_url = "https://raw.githubusercontent.com/mulberrysymbols/mulberry-symbols/#{github_tag}/EN/#{symbol[:symbol]}.svg"

            if symbol[:grammar].downcase == 'letter'
              pos = 'noun'
            elsif symbol[:grammar].downcase == 'verbcomplex'
              pos = 'verb'
            else
              pos = symbol[:grammar].downcase
            end

            image_filename = Rails.root.join('tmp', "gs-import-symbolset-straight_street-#{uuid}-#{symbol[:symbol]}.svg")

            begin
              filename_in_archive = wrong_filename_mappings[symbol[:symbol].to_sym] || symbol[:symbol]
              imagestream = zip.glob("EN-symbols/#{filename_in_archive}.svg").first

              # If no SVG was found, add this symbol to the list of missing_files
              unless imagestream.present?
                missing_files << symbol[:symbol]
                next
              end

              imagestream.extract(image_filename)

              file = File.open(image_filename)

              picto = symbolset.pictos.create_with(
                source: source,
                part_of_speech: pos,
                images: [Image.new(imagefile: file)],
                labels: [
                  Label.new(
                    language: english,
                    source: source,
                    text: symbol[:symbol].titleize,
                    description: "#{symbol[:grammar]}: #{symbol[:tags]}",
                  )
                ]
              ).find_or_create_by(
                publisher_ref: symbol[:symbol],
                symbolset_id: symbolset.id,

              )
            ensure
              File.delete(image_filename) if File.exists? image_filename
            end
          end

          # No concepts found for the symbol?
          if picto.concepts.empty?
            
            label = symbol[:symbol].titleize
            
            # Try removing " Lower Case" from the end of the string
            picto.add_concept(label.sub(/ Lower Case$/, ''), english) if label =~ / Lower Case$/

            # Try removing "Country " and "Country The" from the beginning of the string
            picto.add_concept(label.sub(/^Country (The )?/, ''), english) if label =~ /^Country (The )?/

            # Try removing "Flag " and "Flag The" from the beginning of the string
            picto.add_concept(label.sub(/^Flag (The )?/, ''), english) if label =~ /^Flag (The )?/

            # Try removing " Man" from the end of the string
            picto.add_concept(label.sub(/ man$/i, ''), english) if label =~ / man$/i

            # Try removing " Lady" from the end of the string
            picto.add_concept(label.sub(/ lady$/i, ''), english) if label =~ / lady$/i

            # Replace 'air person' with Pilot
            picto.add_concept('pilot', english) if label =~ /^air person/i

            # Replace 'care assistant 3z' with carer
            picto.add_concept('carer', english) if label =~ /^care assistant/i

            # Cook chef is just a chef
            picto.add_concept('chef', english) if label =~ /^cook chef/i

            # School cook is a caterer
            picto.add_concept('caterer', english) if label =~ /^cook school/i

            # Anything beginning 'dinner' is dinner
            picto.add_concept('dinner', english) if label =~ /^dinner /i

            # Hot drinks
            picto.add_concept('hot drink', english) if label =~ /^drink hot /i

            # Drinks
            picto.add_concept('drink', english) if label =~ /^drink /i

            # Physiotherapist
            picto.add_concept('physiotherapist', english) if label =~ /^physio therapist /i

            # Football kit
            picto.add_concept('football team', english) if label =~ /^football kit /i

            # Post person
            picto.add_concept('postperson', english) if label =~ /^post person /i

            # Speech therapists
            picto.add_concept('speech therapist', english) if label =~ /^speech language therapist /i

            # Various triangles
            picto.add_concept('triangle', english) if label =~ /^triangle /i

            # Use first word if it's 'clothes'
            picto.add_concept('clothes', english) if label =~ /^clothes /i

            # Use first word if ending 'paternal' or 'maternal'
            picto.add_concept(label.sub(/ [pm]aternal$/i, ''), english) if label =~ / [pm]aternal$/i

            # last word becomes first word (e.g. egg boiled => boiled egg)
            picto.add_concept(label.sub(/(.+) ([a-z]+)( \d+\w?)?$/i, '\2 \1'), english) if label =~ /(.+) ([a-z]+)( \d+\w?)?$/i
          end
        end
      end

    ensure
      File.delete(zip_filename) if File.exists? zip_filename
    end

    missing_files
  end
end
