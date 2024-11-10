class SymbolsetMaintenance::MulberryImportTaggedJob < ApplicationJob
  queue_as :default

  # Replaces Mulberry SVG files with versions from the tmp/mulberry-tagged directory.
  def perform(*args)
    symbolset = Symbolset.find_by!(slug: 'mulberry')

    source_directory = Rails.root.join('tmp/mulberry-tagged')

    svg_files = Dir.glob("*.svg", base: source_directory)

    svg_files.each do |filename|
      symbol = symbolset.pictos.find_by!(publisher_ref: filename.delete_suffix('.svg'))

      symbol.images.first.update!(imagefile: File.open(Rails.root.join('tmp/mulberry-tagged', filename)), adaptable: true)
    end
  end
end
