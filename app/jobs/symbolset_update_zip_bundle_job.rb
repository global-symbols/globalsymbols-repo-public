class SymbolsetUpdateZipBundleJob < ApplicationJob
  queue_as :default

  def perform(symbolset, *args)
    
    require 'zip'
    Zip.unicode_names = true
    
    # Generate a random filename for the temporary zip file
    zip_filename = Rails.root.join('tmp', "gs-temp-symbolset-bundle-#{SecureRandom.uuid}.zip")
    
    # Open the temporary zip file
    Zip::File.open(zip_filename, Zip::File::CREATE) do |zip_file|
      # Add the latest version of each Picto's image file to the zip file
      symbolset.pictos.where(archived: false, visibility: :everybody).each do |picto|
        # The filename for the picto inside the zip. e.g. symbol_label_999.png
        # Sanitize in a way that does not strip Cyrillic characters.
        picto_filename = "#{picto.labels.first.text}_#{picto.id}.#{picto.images.last.imagefile.file.extension.downcase}"
        picto_filename = ActiveStorage::Filename.new(picto_filename).sanitized

        zip_file.add(picto_filename, picto.images.last.imagefile.file.path)
      end
    end
    
    # Attach the temporary zip file to the Symbolset
    symbolset.zip_bundle.attach(io: File.open(zip_filename), filename: "#{symbolset.slug}.zip", content_type: 'application/zip')
    
    # Remove the temporary file
    File.delete(zip_filename) if File.exists? zip_filename
  end
end
