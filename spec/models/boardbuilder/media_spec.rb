require 'rails_helper'

RSpec.describe Boardbuilder::Media, type: :model do

  context 'with a png image provided' do

    after :each do
      @owned_media.destroy
    end

    it 'creates an UploadedImage' do
      @owned_media = FactoryBot.create(:media)
      expect(@owned_media).to be_a(Boardbuilder::Media)
      expect(@owned_media.user).to be_a(User)

      expect(@owned_media.height).to eq 300
      expect(@owned_media.width).to eq 300
      expect(@owned_media.filesize).to be >= 50000
      expect(@owned_media.format).to eq 'image/png'
    end
  end

  context 'with a jpg image provided' do
    it 'creates an UploadedImage' do
      @owned_media = FactoryBot.create(:media, file_format: :jpg)

      expect(@owned_media.height).to eq 300
      expect(@owned_media.width).to eq 300
      expect(@owned_media.filesize).to eq 20963
      expect(@owned_media.format).to eq 'image/jpeg'
    end
  end

  context 'with a svg image provided' do
    it 'creates an UploadedImage' do
      @owned_media = FactoryBot.create(:media, file_format: :svg)

      expect(@owned_media.height).to eq 100
      expect(@owned_media.width).to eq 100
      expect(@owned_media.filesize).to eq 27123
      expect(@owned_media.format).to eq 'image/svg+xml'
    end
  end

  context 'with canvas JSON and image provided' do
    it 'creates an UploadedImage with canvas and file populated' do
      @owned_media = FactoryBot.create(:media, :with_canvas, file_format: :svg)

      expect(@owned_media.canvas.file.exists?).to eq true
      expect(@owned_media.file.file.exists?).to eq true
    end
  end
end
