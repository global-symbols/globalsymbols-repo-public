class SymbolsetImporter
  
  attr_accessor :valid, :data
  @valid = false
  
  def initialize(csv, symbolset)
    @csv = csv
    @symbolset = symbolset
    validate_csv
  end
  
  def validate_csv
    begin
      @data = SmarterCSV.process @csv, {
          header_validations: [
              required_headers: [:part_of_speech,:filename,:category,:publisher_ref]
          ],
          hash_validations: [
              required_fields: [:part_of_speech,:filename]
          ]
      }
      
      # Validate presence of label fields
      label_cols = @data.first.select { |key, value| key.to_s.starts_with? 'label_' }.keys
      
      # If no label columns were found, raise an error
      raise CsvMissingRequiredHeadersException if label_cols.empty?
      
      # Validate languages in provided label fields
      # For each provided label column...
      label_cols.each do |key|
        # Find the language by removing the 'label_' prefix from the column name (e.g. label_en)
        language_id = key.to_s.sub 'label_', ''
        # Try to find a matching language
        language = Language.where(iso639_1: language_id).or(Language.where(iso639_3: language_id)).first!
      end
    
    rescue ActiveRecord::RecordNotFound
      raise CsvLanguageNotFoundException
    rescue SmarterCSV::MissingHeaders
      raise CsvMissingRequiredHeadersException
    rescue SmarterCSV::DuplicateHeaders
      raise CsvDuplicateHeadersException
    end
    
    raise CsvMissingRequiredValuesException.new(SmarterCSV.errors) if SmarterCSV.errors.any?
    @valid = true
  end
  
  def import

    # The data source is direct from GS
    source = Source.find_by!(slug: 'global-symbols')

    @data.each do |symbol_attributes|
      filename = symbol_attributes[:filename]
      category = symbol_attributes[:category]

      labels = []
      
      # Find which Languages have been used in the CSV by looking for columns starting with label_ (e.g. label_en)
      label_languages = symbol_attributes.select { |key| key.to_s.starts_with? 'label_' }.keys
      
      # For each Language found, add a Label in this Language
      label_languages.each do |language|
        language = language.to_s.sub('label_', '') # Convert 'label_en' to 'en'
        
        labels << Label.new(
           language: Language.find_by(iso639_1: language),
           text: symbol_attributes["label_#{language}".to_sym],
           text_diacritised: symbol_attributes["diacritised_label_#{language}".to_sym],
           description: symbol_attributes["description_#{language}".to_sym],
           source: source,
           pulled_at: DateTime.now
        )
      end
      
      picto = @symbolset.pictos.build(
          part_of_speech: symbol_attributes[:part_of_speech],
          publisher_ref: symbol_attributes[:publisher_ref],
          labels: labels,
          source: source,
          pulled_at: DateTime.now
      )
      picto.images << FactoryBot.create(:image)
      
      picto.save!
    end
  end
end