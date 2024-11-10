require 'rails_helper'

RSpec.describe SymbolsetSync::GuemilJob, type: :job do
  
  before :all do
    @path = Rails.root.join 'spec', 'fixtures', 'symbolset_sources', 'guemil', 'guemil-v15.zip'
  end
  
  context 'When no Guemil symbols are present in the database' do
    it 'Creates the Symbolset and adds the symbols' do
      expect{
        SymbolsetSync::GuemilJob.perform_now(@path)
      }.to change(Symbolset, :count).by(1)
      .and change(Picto, :count).by(3)
    end
    
    it 'Adds Labels by the Filename' do
      SymbolsetSync::GuemilJob.perform_now(@path)
      expect(Picto.find_by!(publisher_ref: '24_Warning_volcano_v15').labels.first.text).to eq 'Warning volcano'
    end
  end

  context 'When Guemil symbols are present in the database' do
    before :each do
      SymbolsetSync::GuemilJob.perform_now(@path)
    end
  
    it 'Adds symbols that are missing from the database' do
      symbolset = Symbolset.find_by(slug: :guemil)
      
      # Delete an existing Guemil symbol
      deleted_picto = symbolset.pictos.last
      deleted_symbol_ref = deleted_picto.publisher_ref
      deleted_picto.destroy
    
      expect {
        SymbolsetSync::GuemilJob.perform_now(@path)
      }.to change(Symbolset, :count).by(0)
      .and change(Picto, :count).by(1)
    
      expect(symbolset.pictos.last.publisher_ref).to eq deleted_symbol_ref
    end
  end

end
