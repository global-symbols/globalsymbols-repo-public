require 'rails_helper'

RSpec.describe SymbolsetSync::OchaJob, type: :job do
  context 'When no OCHA symbols are loaded' do
    it 'Adds all OCHA symbols' do
      expect{
        SymbolsetSync::OchaJob.perform_now("https://ocha.un/icons.zip")
      }.to change(Symbolset, :count).by(1)
      .and change(Picto, :count).by(6)
    end
  end
  
  context 'when OCHA symbols are already loaded' do
    before :each do
      SymbolsetSync::OchaJob.perform_now("https://ocha.un/icons.zip")
    end
    
    context 'with missing Symbols' do
      before :each do
        # Make a symbol missing!
        Symbolset.find_by(slug: 'ocha-humanitarian-icons').pictos.last.destroy!
      end

      it 'Adds only missing Symbols' do
        expect{
          SymbolsetSync::OchaJob.perform_now("https://ocha.un/icons.zip")
        }.to change(Symbolset, :count).by(0)
        .and change(Picto, :count).by(1)
      end
    end
    
    context 'with updated Symbols' do
      it 'Loads updated Symbols' do
        airport = Symbolset.find_by(slug: 'ocha-humanitarian-icons').pictos.find_by!(publisher_ref: 'Airport-closed')
        image = airport.images.first
        expect(image.reload.imagefile.read).to_not include 'UPDATED-AIRPORT'
        expect{
          SymbolsetSync::OchaJob.perform_now("https://ocha.un/icons-with-airport-updated.zip")
          # SymbolsetSync::OchaJob.perform_now("https://ocha.un/icons.zip")
        }.to change(Symbolset, :count).by(0)
        .and change(Picto, :count).by(0)
        .and change{image.reload.imagefile.read}
    
        expect(image.reload.imagefile.read).to include 'UPDATED-AIRPORT'
      end
    end
  end
end
