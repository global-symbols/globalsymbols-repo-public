require 'rails_helper'

RSpec.describe SymbolsetSync::ArasaacJob, type: :job do
  before :each do

    # Stubs for successful calls to the ARASAAC API

    # Calls to the list of new Pictos (limited by number) at ARASAAC
    stub_request(:get, Addressable::Template.new("https://api.arasaac.org/api/pictograms/{language}/new/{count}")).
      to_return(File.new(Rails.root.join('spec/fixtures/symbolset_sync_sources/arasaac-api-pictograms-en-new-5.txt')))

    # Calls to the list of new Pictos (limited by days) at ARASAAC
    stub_request(:get, Addressable::Template.new("https://api.arasaac.org/api/pictograms/{language}/days/{count}")).
      to_return(File.new(Rails.root.join('spec/fixtures/symbolset_sync_sources/arasaac-api-pictograms-en-new-5.txt')))

    # Calls to the list of Labels at ARASAAC
    stub_request(:get, Addressable::Template.new("https://api.arasaac.org/api/pictograms/all/{language}")).
      to_return(File.new(Rails.root.join('spec/fixtures/symbolset_sync_sources/arasaac-api-pictograms-en-all-5.txt')))

    # Calls to specific Picto imagefiles at ARASAAC
    stub_request(:get, Addressable::Template.new("https://static.arasaac.org/pictograms/{id}/{filename}.png")).
      to_return(body: File.new(Rails.root.join('spec/fixtures/picto.image.imagefile.png')),
                status: 200,
                headers: {
                  'Content-Type': 'image/png'
                })

    # Next, stub calls to a non-existent locale ('fof', for 404)
    # These stubs must be defined after the 'successful' stubs.

    # Calls to a missing locale for the list of new Pictos (limited by number) at ARASAAC
    stub_request(:get, Addressable::Template.new("https://api.arasaac.org/api/pictograms/fof/new/{count}")).
      to_return(status: 404)

    # Calls to a missing locale for the list of new Pictos (limited by days) at ARASAAC
    stub_request(:get, Addressable::Template.new("https://api.arasaac.org/api/pictograms/fof/days/{count}")).
      to_return(status: 404)

    # Calls to a missing locale for the list of Labels at ARASAAC
    stub_request(:get, Addressable::Template.new("https://api.arasaac.org/api/pictograms/all/fof")).
      to_return(status: 404)

    # Configure CarrierWave not to perform SSRF protection.
    # This protection converts hostname requests (e.g. https://test.com) to IP addresses (e.g. https://1.2.3.4)
    # which, of course, are not registered in WebMock.
    allow_any_instance_of(CarrierWave::Downloader::Base).to receive(:skip_ssrf_protection?).
        and_return(true)

    @arasaac = FactoryBot.create(:symbolset, slug: :arasaac, pictos_count: 0)

    @test_locales = ['en', 'fr']
    
    symbols_text = open('https://api.arasaac.org/api/pictograms/en/new/30000')
    @update_data = JSON.load(symbols_text, nil, {object_class: OpenStruct})
    expect(@update_data.count).to eq 5
  end
  context "When no ARASAAC symbols are loaded" do

    before :each do
      expect(@arasaac.pictos.count).to eq 0
    end

    it "Adds all ARASAAC symbols with English and French labels, skipping those without Keywords" do
      expect{
        SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
      }.to change(Symbolset, :count).by(0)
      .and change(Picto, :count).by(4)
      .and change(Label, :count).by(8)
      .and change(Image, :count).by(4)
      .and change{Source.find_by(slug: :api).pictos.count}.by(4)

      expect(@arasaac.reload.pictos.count).to eq 4

      expect(Picto.last.labels.first.language).to eq Language.find_by(iso639_1: :en)
    end

    it "Adds Labels with pulled_at and source attributes" do
      SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)

      @arasaac.reload

      # For each symbol in the source JSON...
      @update_data.each_with_index do |source_symbol, index|
        next if source_symbol.keywords.empty?

        # Find the label for the imported symbol
        label = @arasaac.pictos.find_by(publisher_ref: source_symbol._id).labels.first

        # puts "index #{index} #{symbol.labels.first.text} #{symbol.part_of_speech} #{source_symbol.keywords.first.type}"

        expect(label.pulled_at).to be_within(2.seconds).of Time.now.utc
        expect(label.source.slug).to eq 'api'
        expect(label.text).to eq source_symbol.keywords.first.keyword
        expect(label.description).to eq source_symbol.keywords.first.meaning
      end
    end

    it "Sets Symbols with pulled_at and source attributes" do
      SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)

      @arasaac.reload

      # For each symbol in the source JSON...
      @update_data.each_with_index do |source_symbol, index|
        next if source_symbol.keywords.empty?

        pp source_symbol._id

        # Find the imported symbol
        symbol = @arasaac.pictos.find_by(publisher_ref: source_symbol._id)

        expect(symbol.pulled_at).to be_within(2.seconds).of Time.now.utc
        expect(symbol.source.slug).to eq 'api'

        # The 4th symbol in the fixture is an adjective. The rest are nouns.
        expected_pos = (index == 2) ? 'verb' : 'noun'
        expect(symbol.part_of_speech).to eq expected_pos
      end
    end

    it 'Sets the API Source on Labels and Pictos' do
      expect{
        result = SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
      }.to change{Source.find_by(slug: :api).labels.count}.by(8)
      .and change{Source.find_by(slug: :api).pictos.count}.by(4)
    end
  end
  
  context 'When some ARASAAC symbols are already loaded' do
    context 'When some new symbols are found on the ARASAAC API' do
      before :each do
        @removed_symbols = 2

        # Load all new ARASAAC symbols and then delete two
        SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
        Symbolset.find_by!(slug: :arasaac).pictos.limit(@removed_symbols).destroy_all
      end
      it 'loads new ARASAAC symbols' do
        expect{
          SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
        }.to change(Symbolset, :count).by(0)
        .and change(Picto, :count).by(@removed_symbols)
        .and change(Label, :count).by(@removed_symbols * @test_locales.count)
      end
    end

    context 'when there are no new updates from ARASAAC' do
      before :each do
        # Load in the existing symbols, pretending they were loaded in the past, but AFTER the last ARASAAC update
        travel_to Time.local(2019, 11, 1)
        SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
        expect(@arasaac.pictos.pluck :created_at).to all be_within(2.seconds).of DateTime.now
        expect(@arasaac.pictos.pluck :updated_at).to all be_within(2.seconds).of DateTime.now
        expect(@arasaac.pictos.pluck :pulled_at).to all be_within(2.seconds).of DateTime.now
        travel_back
      end
      
      it 'does not update symbols that HAVE NOT been updated by ARASAAC' do
        expect{
          SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
        }.to_not change{@arasaac.reload.pictos.first}
      end
    end
    
    context 'when there are updates from ARASAAC' do
      before :each do
        # Load in the existing symbols, pretending they were loaded in the past, but BEFORE the last ARASAAC update
        @before_last_arasaac_update = Time.local(2019, 9, 1)
        travel_to @before_last_arasaac_update
        SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
        expect(@arasaac.pictos.pluck :created_at).to all be_within(2.seconds).of DateTime.now
        expect(@arasaac.pictos.pluck :updated_at).to all be_within(2.seconds).of DateTime.now
        expect(@arasaac.pictos.pluck :pulled_at).to all be_within(2.seconds).of DateTime.now
        travel_back
      end

      it 'updates symbol images that HAVE been updated by ARASAAC' do
        @symbol = @arasaac.pictos.first
        @image = @symbol.images.first
        
        expect(@symbol.reload.pulled_at).to eq @before_last_arasaac_update
        expect(@image.reload.updated_at).to eq @before_last_arasaac_update
        
        expect{
          SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
        }.to change{@symbol.reload.pulled_at}.from(@before_last_arasaac_update).to(be_within(2.seconds).of DateTime.now)
        .and change{@image.reload.imagefile}
        .and change{@image.reload.updated_at}.from(@before_last_arasaac_update).to(be_within(2.seconds).of DateTime.now)

        expect(@symbol.reload.pulled_at.utc).to be_within(2.seconds).of DateTime.now.utc
        expect(@image.reload.updated_at.utc).to be_within(2.seconds).of DateTime.now.utc
      end
      
      it 'deletes the old symbol image file' do
        @symbol = @arasaac.pictos.first
        @image = @symbol.images.first
        
        old_imagefile_path = @image.imagefile.path
        expect(File).to exist(old_imagefile_path)
        
        # The old file should be deleted after the update
        SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
        expect(File).to_not exist(old_imagefile_path)
        
        # The new file should have been created
        expect(File).to exist(@image.reload.imagefile.path)
      end
    end
  end

  context 'When some ARASAAC symbols have new Labels in the API' do
    before :each do
      # Load all new ARASAAC symbols and then change the label on one
      SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
      @changed_label = Symbolset.find_by!(slug: :arasaac).pictos.first.labels.first
      @api_text = @changed_label.text
      @changed_label.update!(text: 'OLD TEXT')
    end

    it 'Updates labels to match the API' do
      expect{
        SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
      }.to change{@changed_label.reload.text}.from('OLD TEXT').to(@api_text)
    end
  end

  context "When given a Language that doesnt exist in the database" do
    it 'Quietly skips the language' do
      result = SymbolsetSync::ArasaacJob.perform_now(source_locales: ['en', 'xy'])

      pp result.inspect
      expect(result['en'].language_found).to eq true
      expect(result['xy'].language_found).to eq false
    end
  end
  
  context "When a locale is not available on the ARASAAC API" do
    before :each do
      FactoryBot.create(:language, iso639_1: 'ff', iso639_3: 'fof', name: 'Four-o-Four!')
    end
    it "Continues with other locales" do
      result = SymbolsetSync::ArasaacJob.perform_now(source_locales: ['fof', 'en'])

      pp result.inspect
      expect(result['fof'].api_response).to eq 404
      expect(result['en'].api_response).to eq 200
    end
  end

  context 'When importing is complete' do
    it 'Sets the Symbolset.pulled_at date to the start date/time of the import' do
      @start_time = DateTime.now
      expect{
        SymbolsetSync::ArasaacJob.perform_now(source_locales: @test_locales)
      }.to change{@arasaac.reload.pulled_at}.to be_within(1.second).of @start_time
    end
  end
end
