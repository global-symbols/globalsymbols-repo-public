require 'rails_helper'

RSpec.describe SymbolsetImport::ScleraJob, type: :job do
  before :all do
    @symbols = JSON.parse(File.read(Rails.root.join('spec/fixtures/symbolset_sources/sclera/dump-from-pictoselector.fixture.json')))
    @images_directory = 'spec/fixtures/symbolset_sources/sclera/dump-from-pictoselector.fixture'
  end
  
  context 'When no Sclera symbols are loaded' do
    it 'Adds all Sclera symbols' do
      expect{
        SymbolsetImport::ScleraJob.perform_now(@symbols, @images_directory)
      }.to change(Symbolset, :count).by(1)
      .and change(Picto, :count).by(6)
    end
    
    it 'Does not import non-Sclera images' do
      expect{
        SymbolsetImport::ScleraJob.perform_now(JSON.parse('[{
          "local_filename": "ARASAAC Symbol Set\\\\24073.png",
          "url": "http://www.pecsforall.com/pecs/ARASAAC%20Symbol%20Set/24073.png",
          "descriptions": {
            "ar": "الغلاف الأرضي",
            "ca": "geosfera"
          },
          "id": 17022
        }]'), @images_directory)
      }.to change(Picto, :count).by(0)
      .and change(Label, :count).by(0)
    end
    
    it 'does not import Labels that are blank' do
      expect{
        SymbolsetImport::ScleraJob.perform_now(JSON.parse('[{
          "local_filename": "auto 2.png",
          "url": "http://www.pecsforall.com/pecs/auto%202.png",
          "descriptions": {
            "ar": "    ",
            "en": "car"
          },
          "id": 182
        }]'), @images_directory)
      }.to change(Picto, :count).by(1)
      .and change(Label, :count).by(1)
    end
    
    it 'Uppercases the first letters of non-AR language labels' do
      SymbolsetImport::ScleraJob.perform_now(JSON.parse('[{
        "local_filename": "auto 2.png",
        "url": "http://www.pecsforall.com/pecs/auto%202.png",
        "descriptions": {
          "ar": "سيارة",
          "en": "car"
        },
        "id": 182
      }]'), @images_directory)
      sclera = Symbolset.find_by slug: :sclera
      picto = sclera.pictos.first
      expect(picto.labels.pluck :text).to include 'سيارة'
      expect(picto.labels.pluck :text).to include 'Car'
    end
    
    describe 'concatenated symbol descriptions' do
      context 'joined with a slash' do
        it 'adds multiple Labels for symbols with concatenated descriptions'do
          expect{
            SymbolsetImport::ScleraJob.perform_now(JSON.parse('[{
              "local_filename": "auto 2.png",
              "url": "http://www.pecsforall.com/pecs/auto%202.png",
              "descriptions": {
                "en": "do the dishes / washing up /  "
              },
              "id": 182
            }]'), @images_directory)
          }.to change(Picto, :count).by(1)
          .and change(Label, :count).by(2)

          picto = Symbolset.find_by(slug: :sclera).pictos.first
          expect(picto.labels.pluck :text).to match_array ['Do The Dishes', 'Washing Up']
        end
      end
  
      context 'joined with a comma' do
        it 'adds multiple Labels for symbols with concatenated descriptions'do
          expect{
            SymbolsetImport::ScleraJob.perform_now(JSON.parse('[{
              "local_filename": "auto 2.png",
              "url": "http://www.pecsforall.com/pecs/auto%202.png",
              "descriptions": {
                "de": "Kuchen,, Torte , Schokoladenkuchen"
              },
              "id": 182
            }]'), @images_directory)
          }.to change(Picto, :count).by(1)
          .and change(Label, :count).by(3)
          
          picto = Symbolset.find_by(slug: :sclera).pictos.first
          expect(picto.labels.pluck :text).to match_array ['Kuchen', 'Torte', 'Schokoladenkuchen']
        end
      end
    end
    
    
  end
  
  context 'When Sclera symbols are already loaded' do
    before :each do
      # Load the Symbol Set
      SymbolsetImport::ScleraJob.perform_now(@symbols, @images_directory)
      @sclera = Symbolset.find_by slug: :sclera
    end
    
    it 'loads only missing symbols' do
      # Delete a symbol.
      @sclera.pictos.last.destroy!
      
      # Check that it is re-added.
      expect{
        SymbolsetImport::ScleraJob.perform_now(@symbols, @images_directory)
      }.to change(Symbolset, :count).by(0)
      .and change(Picto, :count).by(1)
    end
  end
end
