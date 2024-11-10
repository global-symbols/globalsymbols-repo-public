class ImportLanguagesJob < ApplicationJob
  queue_as :default

  require 'open-uri'
  require 'csv'

  # This importer has been adjusted to ignore changes to ISO639_3 codes at SIL.
  # Some countries appear to change their codes, which creates havoc with the table.
  # For now, these codes will not be updated, but new codes will be imported.
  
  # Downloads the list of ISO639 languages from SIL and adds them to the Languages table.
  # Downloads the list of specific-to-macrolanguage associations from SIL and creates associations on Languages.
  #
  # WARNING: The SIL lists of ISO639 "individual languages" and "macro-languages" can sometimes be inconsistent.
  # i.e. ISO639-3 codes used to define a macro-language sometimes don't exist in the individual language list.
  def perform(*args)
    # First import all the language definitions
    import_languages
    
    # Then map individual languages to macro-languages (e.g. Gulf Arabic -> Arabic)
    import_macrolanguage_mappings

    # Languages are created as inactive, to keep dropdown menus a sensible size. We enable a few defaults.
    ActivateLanguagesJob.perform_now
  end
  
  private
    def import_languages

      languages = get_sil_table('https://iso639-3.sil.org/sites/iso639-3/files/downloads/iso-639-3.tab')
      
      # Astonishingly, SIL's *OFFICIAL* list of languages contains a blank line after mww.
      # So we have to remove blank lines. Doing that here by removing lines that don't have an ID
      languages.delete_if {|l| l[:id].nil?}
      
      # For each language
      languages.each do |language|

        language.each_value{|v| v = v.try :strip}

        # Create the Language if it doesn't exist, mapping the SIL fields onto our own
        Language.create!({
          iso639_3:  language[:id],
          iso639_2b: language[:part2b],
          iso639_2t: language[:part2t],
          iso639_1:  language[:part1],
          scope:     language[:scope],
          category:  language[:language_type],
          name:      language[:ref_name]
        }) if Language.unscoped.where(iso639_3: language[:id]).or(Language.unscoped.where(name: language[:ref_name])).count === 0
      end
    end
  
    def import_macrolanguage_mappings
      mappings = get_sil_table('https://iso639-3.sil.org/sites/iso639-3/files/downloads/iso-639-3-macrolanguages.tab')
      
      mappings.each do |mapping|
        # Skip non-active (A) mappings, such as retired (R, deprecated) mappings.
        next if mapping[:i_status] != 'A'
        
        # We have to find Languages with .unscoped because the default scope limits which Languages are returned.
        # We wrap the lookups in a begin/rescue block in case a record does not exist.
        begin
          macrolanguage = Language.unscoped.find_by!(iso639_3: mapping[:m_id])
          individual_language = Language.unscoped.find_by!(iso639_3: mapping[:i_id])
        rescue ActiveRecord::RecordNotFound => e
          pp "Could not find a Language while mapping macro-language #{mapping[:m_id]} to individual language #{mapping[:i_id]}"
          pp e.message

          # Quietly continue when a Macro or Individual language cannot be found.
          # SIL's macro-langauges mapping table appears slow to receive updated ISO639 codes,
          # meaning the table of individual languages and macro-languages can sometimes be inconsistent!
          next
        end

        
        # Assign the macrolanguage to the individual language
        individual_language.update(macrolanguage: macrolanguage)
      end
    end
    
    # @param  url The URL of the table file to download. SILs .tab files are UTF8 TSV format.
    # @return A hash of the parsed table file from 'url', decoded from UTF8 with headers converted to symbols.
    def get_sil_table(url)
      CSV.parse(open(url, "r:UTF-8"), { col_sep: "\t" , headers: true, header_converters: :symbol }).map(&:to_h)
    end
end
