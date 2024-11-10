require 'rails_helper'

RSpec.describe SymbolsetSync::OpenmojiJob, type: :job do
  before :all do
    # @symbols = JSON.parse(File.read(Rails.root.join('spec/fixtures/symbolset_sources/sclera/dump-from-pictoselector.fixture.json')))
    # @images_directory = 'spec/fixtures/symbolset_sources/sclera/dump-from-pictoselector.fixture'
    @openmoji_version = '12.3.0'
  end
  
  context 'When no Openmoji symbols are present in the database' do
    it 'Creates the Symbolset and adds the symbols' do
      expect{
        SymbolsetSync::OpenmojiJob.perform_now(@openmoji_version)
      }.to change(Symbolset, :count).by(1)
      .and change(Picto, :count).by(4)
    end
    
    it 'Adds Labels for the symbol annotation and openmoji_tags' do
      SymbolsetSync::OpenmojiJob.perform_now(@openmoji_version)
      expect(Picto.find_by!(publisher_ref: '1F600').labels.pluck :text).to match_array ['Grinning Face', 'Happy', 'Smile']
    end
  end
  
  context 'When Openmoji symbols are present in the database' do
    before :each do
      SymbolsetSync::OpenmojiJob.perform_now(@openmoji_version)
    end
    
    it 'Adds symbols that are missing from the database' do
      symbolset = Symbolset.find_by(slug: :openmoji)
      # Delete an existing OpenMoji symbol
      deleted_picto = symbolset.pictos.last
      deleted_symbol_ref = deleted_picto.publisher_ref
      deleted_picto.destroy
      
      expect{
        SymbolsetSync::OpenmojiJob.perform_now(@openmoji_version)
      }.to change(Symbolset, :count).by(0)
      .and change(Picto, :count).by(1)
      
      expect(symbolset.pictos.last.publisher_ref).to eq deleted_symbol_ref
    end
  end
end
