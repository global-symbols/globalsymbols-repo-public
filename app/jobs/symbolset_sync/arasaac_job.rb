module SymbolsetSync
  class ArasaacJob < ApplicationJob
    queue_as :default

    # ARASAAC updates run in two stages.
    # 1. Load all new/updated symbols into Pictos table
    # 2. Load all new/updated translations into Labels table
    # @param [Integer] limit Limits the number of new symbols to request from the ARASAAC API
    # @param [array[string]] locales List of ARASAAC locales to load translations from. Leave blank to load all locales.
    # @param [Boolean] full_update When true, the updater will load all ARASAAC symbols. When false, an incremental update is performed.
    def perform(
      source_locales: %w(an ar bg br ca de el en es et eu fa fr gl he hr hu it mk nl pl pt ro ru sk sq sv sr val zh),
      full_update: false
    )

      start_time = DateTime.now

      # WARNING: ARASAAC mix ISO639-1 and ISO639-3 codes
      @source_locales = source_locales
      @full_update = full_update

      @api_source = Source.find_by!(slug: :api)

      # Create or find the ARASAAC symbol set
      @arasaac = Symbolset.create_with(
        name: 'ARASAAC',
        publisher: 'Government of Aragón',
        publisher_url: 'https://arasaac.org',
        licence: Licence.find_by!(version: '4.0', properties: 'by-nc-sa')
      ).find_or_create_by!(slug: 'arasaac')

      # If the symbolset has never been updated, force a full update
      if @arasaac.pulled_at.nil?
        @full_update = true
      else
        @days_since_last_update = (Date.today - @arasaac.pulled_at.to_date).to_i
      end

      # Run the update
      result = update_symbol_set

      # Stamp the ARASAAC symbolset with the update time
      @arasaac.update!(pulled_at: start_time)

      result

    end

    private

      # Loads new Symbol images and labels in various languages from the ARASAAC API.
      def update_symbol_set

        output = {}

        puts "Updating ARASAAC for locales: #{@source_locales}"

        @source_locales.each do |locale_code|

          # We'll store some stats for the locale processing here
          output[locale_code] = template_results(locale_code)

          # ARASAAC mix ISO639-1 and ISO639-3 codes, so we need to search for both
          language = Language.where(iso639_1: locale_code).or(Language.where(iso639_3: locale_code)).limit(1).first
          if !language
            puts "Language #{locale_code} not found"
            next
          end

          # Mark the language as found
          output[locale_code].language_found = true

          puts "Downloading new symbols for #{locale_code} Language from ARASAAC API"

          # Download incremental updates from ARASAAC, in the language specified by locale_code.
          # If @days_since_last_update is not set or @full_update is true, all symbols will be updated.
          if @days_since_last_update and !@full_update
            # We add 1 to @days_since_last_update so that we have some overlap, and
            # so that updates are loaded even if the updater is run twice on the same day.
            url = "https://api.arasaac.org/api/pictograms/#{locale_code}/days/#{@days_since_last_update + 1}"
          else
            url = "https://api.arasaac.org/api/pictograms/all/#{locale_code}"
          end

          begin
            updated_symbols = JSON.load(open(url), nil, { object_class: OpenStruct})
          rescue OpenURI::HTTPError => e
            puts 'ARASAAC API error'
            puts e.message
            output[locale_code].api_response = 404
            next
          end

          output[locale_code].api_response = 200

          puts "Received #{updated_symbols.count} symbols from ARASAAC API"

          # Loop over each returned symbol
          updated_symbols.each do |symbol|

            # next unless symbol._id == 2517

            puts "ARASAAC #{symbol._id} in #{locale_code}: Starting."

            symbol.lastUpdated = DateTime.parse symbol.lastUpdated

            output[locale_code].processed += 1

            # If the symbol has no _id field, log to bad_api_data and continue.
            # ARASAAC appear to change the structure of data they return without versioning the API,
            # so we have to be careful to catch these cases.
            output[locale_code].bad_api_data += 1 and next if symbol._id.nil?

            # Remove any keywords that are nil (null) or empty strings.
            # For some reason, these are included in ARASAAC responses.
            symbol.keywords.select!{ |keyword| keyword.keyword.present? }

            # Skip the symbol if it has no keywords.
            output[locale_code].missing_keywords += 1 and next if symbol.keywords.empty?

            begin
              # Try to find the picto in our database
              # If this fails, the rescue block will add a new Picto with the label and image.
              picto = @arasaac.pictos.find_by!(publisher_ref: symbol._id)
              log "ARASAAC #{symbol._id}: Picto found in database with ID #{picto.id}."

              # if !force_update_all_images
              if picto_needs_update(picto, symbol)
                log "ARASAAC #{symbol._id}: Updating Image."

                begin
                  # Update the Image file
                  picto.images.first.update!(
                    remote_imagefile_url: "https://static.arasaac.org/pictograms/#{symbol._id}/#{symbol._id}_500.png"
                  )

                  log "ARASAAC #{symbol._id}: Updating Picto metadata..."
                  # Stamp the Picto with the pulled_at time and update part_of_speech
                  # TODO: Update part_of_speech for English only - we don't know if PoS keys vary between languages.
                  picto.update!(
                    pulled_at: DateTime.now,
                    source: @api_source,
                    part_of_speech: map_part_of_speech(symbol.keywords.first.type.to_i)
                  )
                rescue ActiveRecord::RecordInvalid => error
                  # Quietly log the error
                  output[locale_code].errors << error
                end
              end
              # end

            #  Rescue block to add a Picto if it's missing
            rescue ActiveRecord::RecordNotFound

              # If the picto doesn't exist, then create it
              log "ARASAAC #{symbol._id}: Picto not found in database. Adding with #{locale_code} label #{symbol.keywords.first.keyword}..."

              picto = @arasaac.pictos.create!(
                pulled_at:      Time.now.utc,
                source:         @api_source,
                part_of_speech: map_part_of_speech(symbol.keywords.first.type.to_i),

                publisher_ref:  symbol._id,
                images:         [
                                  Image.new(
                                    remote_imagefile_url: "https://static.arasaac.org/pictograms/#{symbol._id}/#{symbol._id}_500.png"
                                  )
                                ],
                labels:         [
                                  Label.new(label_attributes_from_symbol(symbol, language, @api_source).to_h)
                                ]
              )

              output[locale_code].added += 1
            end


            # Picto will have been found or added by this point. Time to check labels.

            log "ARASAAC #{symbol._id}: Label check for #{locale_code}..."
            begin
              # Try to find an existing label for this language in the database (current design is one label per lang)
              # If this fails, the rescue block will add the Label.
              existing_label = picto.labels.find_by!(language: language)
              log "ARASAAC #{symbol._id}: Label found for #{locale_code}..."

              new_label_attributes = label_attributes_from_symbol(symbol, language, @api_source)

              # If the existing Label has never been updated or is out of date, update it
              if label_needs_update(existing_label, new_label_attributes, symbol.lastUpdated)

                begin
                  log "ARASAAC #{symbol._id}: Updating label with description #{new_label_attributes.description}"
                  existing_label.update!(new_label_attributes.to_h)
                rescue ArgumentError => e
                  # If an invalid byte sequence occurs, then ARASAAC encoding has presented a further problem.
                  # Instead of using the mass result, query the API for just the affected symbol, but with a different
                  # encoding workaround.
                  if e.message == 'invalid byte sequence in UTF-8'
                    log "ARASAAC #{symbol._id}: Invalid byte sequence in UTF-8. Loading symbol from API direct..."
                    encoded_symbol = get_symbol_with_encoding(locale_code, symbol._id)
                    existing_label.update!(
                      label_attributes_from_symbol(encoded_symbol, language, @api_source).to_h
                    )
                  end
                end

                log "ARASAAC #{symbol._id}: Label updated for #{locale_code}..."
              end


            rescue ActiveRecord::RecordNotFound
              log "ARASAAC #{symbol._id}: Label not found for #{locale_code}. Adding..."
              # Add the Picto's label
              picto.labels.create!(label_attributes_from_symbol(symbol, language, @api_source).to_h)
              log "ARASAAC #{symbol._id}: Label added for #{locale_code}."

            end

            output[locale_code].updated += 1

          end

        end

        output
      end

    # Returns true if a Picto in the database needs updating.
    # Compares the Picto against a symbol provided from the ARASAAC API.
    # @param [Object] [picto] A Picto model
    # @param [Object] symbol A symbol entry from the ARASAAC API
    # @return [Boolean] True if the Label needs updating
    def picto_needs_update(picto, symbol)
      # Return true if
      # the Picto is not already loaded from the API OR
      # the Picto has never been updated OR
      # the Picto has been updated at ARASAAC
      # NB: using picto.source_id avoids a query to load the Source
      picto.source_id != @api_source.id or
        picto.pulled_at.nil? or
        picto.pulled_at < symbol.lastUpdated
    end

    # Returns true if a Label in the database needs updating.
    # Compares the Label against a symbol provided from the ARASAAC API.
    # @param [Object] existing_label A Label model
    # @param [Object] new_label_attributes A symbol entry from the ARASAAC API
    # @return [Boolean] True if the Label needs updating
    def label_needs_update(existing_label, new_label_attributes, arasaac_last_update_date)
      # Return true if
      # the Label source is not API OR
      # the Label has never been updated OR
      # the Label is out of date OR
      # the Label text does not match the text provided in the API OR
      # the Label description does not match the description provided in the API
      # NB: using label.source_id avoids a query to load the Source
      existing_label.source_id != @api_source.id or
        existing_label.pulled_at.nil? or
        existing_label.pulled_at < arasaac_last_update_date or
        existing_label.text != new_label_attributes.text or
        existing_label.description != new_label_attributes.description
    end

    def template_results(locale)
      OpenStruct.new({
                       locale: locale,
                       processed: 0,
                       added: 0,
                       updated: 0,
                       skipped: 0,
                       missing_keywords: 0,
                       bad_api_data: 0,
                       language_found: false,
                       api_response: nil,
                       errors: []
                     })
    end

    def map_part_of_speech(arasaac_type_number)
      arasaac_types = {
        1 => :noun,
        2 => :noun,
        3 => :verb,
        4 => :adjective,
        5 => :adjective,
        6 => :modifier
      }

      arasaac_types[arasaac_type_number]
    end

    def label_attributes_from_symbol(symbol, language, source)

      # Not all ARASAAC keywords have a meaning
      description = symbol.keywords.try(:first).try(:meaning).try(:strip)
      # ARASAAC meanings are currently delivered incorrectly encoded, causing UTF-8 characters to be corrupted
      # in languages such as Catalan and Breton (e grave, etc).
      # To fix this, the meaning is encoded to ISO-8859-1 and then forced back to UTF-8.
      # However, hebrew text causes an error when run through this process,
      # so we have to put the operation in a begin/rescue.
      begin
        description = description.encode('iso-8859-1').force_encoding('utf-8') if description
      rescue Encoding::UndefinedConversionError
        # Ignored
      end


      OpenStruct.new({
        pulled_at: DateTime.now,
        language: language,
        source: source,
        text: extract_keyword(symbol),
        description: description
      })
    end

    def extract_keyword(symbol)
      # Remove 'to' on verbs such as 'to run'
      keyword = symbol.keywords.first.keyword
      keyword.delete_prefix!('to ') if symbol.keywords.first.type.to_i == 3
      keyword.try(:strip)
    end

    def log(string)
      # puts string
    end

    # Fetches a single symbol from the ARASAAC API, but with an additional encoding workaround.
    # This works around UTF8 encoding problems on 'meanings' on the ARASAAC API.
    def get_symbol_with_encoding(locale_code, id)
      url = "https://api.arasaac.org/api/pictograms/#{locale_code}/#{id}"
      json = open(url).read.force_encoding('ISO-8859-1').encode('UTF-8')
      symbol = JSON.load(json, nil, { object_class: OpenStruct})
      symbol.lastUpdated = DateTime.parse symbol.lastUpdated
      symbol
    end
  end
end
