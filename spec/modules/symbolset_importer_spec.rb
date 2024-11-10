require 'rails_helper'

fixture_path = 'spec/fixtures'

RSpec.describe SymbolsetImporter, type: :module do
  before :each do
    @symbolset = FactoryBot.create(:symbolset)
  end
  context "with an invalid CSV file" do
    context "with duplicated headers" do
      it "raises a DuplicateHeaders exception" do
        csv = "#{fixture_path}/symbolset.invalid.duplicate_headers.csv"
        expect{SymbolsetImporter.new(csv, @symbolset)}.to raise_exception CsvDuplicateHeadersException
      end
    end
    context "with required headings missing in the CSV file" do
      it "raises a MissingHeaders exception" do
        csv = "#{fixture_path}/symbolset.invalid.missing_headers.csv"
        expect{SymbolsetImporter.new(csv, @symbolset)}.to raise_exception CsvMissingRequiredHeadersException
      end
    end
    context "with required fields empty in the CSV" do
      it "raises a MissingHeaders exception" do
        csv = "#{fixture_path}/symbolset.invalid.missing_data.csv"
        expect{SymbolsetImporter.new(csv, @symbolset)}.to raise_exception CsvMissingRequiredValuesException
      end
    end
  end
  context "with a valid CSV file" do
    it "loads the data successfully" do
      csv = "#{fixture_path}/symbolset.valid.csv"
      expect{SymbolsetImporter.new(csv, @symbolset)}.not_to raise_exception
      importer = SymbolsetImporter.new(csv, @symbolset)
      expect(importer.data.count).to be 5
      expect(importer.valid).to be true
    end
    it "imports Pictos" do
      csv = "#{fixture_path}/symbolset.valid.csv"
      importer = SymbolsetImporter.new(csv, @symbolset)
      importer.import
      # TODO: Test successful import
    end
  end
end
