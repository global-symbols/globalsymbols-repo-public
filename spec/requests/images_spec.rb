require 'rails_helper'

RSpec.describe "Images", type: :request do

  describe "GET #show" do

    [OpenStruct.new({extension: 'png', mime_type: 'image/png'}),
     OpenStruct.new({extension: 'svg', mime_type: 'image/svg+xml'})].each do |format|
      context "With a #{format.extension} file" do
        before :each do
          @picto = FactoryBot.create :picto, :with_published_symbolset, images_file_format: format.extension
          @image = @picto.images.first
          expect(@image.imagefile.file.extension.downcase).to eq format.extension
          expect(@picto.images.count).to eq 1
        end
        it 'returns the Picto even if the route hash is wrong' do
          # Get the imagefile by ID, but with a hash that doesn't match the filename on the filesystem.
          get "/uploads/development/image/imagefile/#{@image.id}/4_4222_f1472ef2-b657-does-not-matcha50320b.#{format.extension}"
          # pp response
          # pp response.body
          expect(response).to redirect_to symbolset_symbol_path(@picto.symbolset, @picto, format: format.extension)

          # Now follow the redirect
          follow_redirect!
          expect(response).to have_http_status(:success)
          expect(response.headers['Content-Type']).to eq format.mime_type
          expect(response.body).to eq @image.imagefile.read
        end
      end
    end


    # context 'with a PNG image' do
    #   before :each do
    #     @picto = FactoryBot.create :picto, :with_published_symbolset, images_file_format: :png
    #     @image = @picto.images.first
    #   end
    #   it 'returns the Picto even if the route hash is wrong' do
    #     # Get the imagefile by ID, but with a hash that doesn't match the filename on the filesystem.
    #     get "/uploads/development/image/imagefile/#{@image.id}/4_4222_f1472ef2-b657-does-not-matcha50320b.png"
    #     # pp response
    #     # pp response.body
    #     expect(response).to redirect_to symbolset_symbol_path(@picto.symbolset, @picto, format: :png)
    #
    #     # Now follow the redirect
    #     follow_redirect!
    #     expect(response).to have_http_status(:success)
    #     expect(response.headers['Content-Type']).to eq 'image/png'
    #     expect(response.body).to eq @image.imagefile.read
    #   end
    # end
    #
    # context 'with a SVG image' do
    #   before :each do
    #     @picto = FactoryBot.create :picto, :with_published_symbolset, images_file_format: :svg
    #     @image = @picto.images.first
    #   end
    #   it 'returns the Picto even if the route hash is wrong' do
    #     # Get the imagefile by ID, but with a hash that doesn't match the filename on the filesystem.
    #     get "/uploads/development/image/imagefile/#{@image.id}/4_4222_f1472ef2-b657-does-not-matcha50320b.svg"
    #     # pp response
    #     # pp response.body
    #     expect(response).to redirect_to symbolset_symbol_path(@picto.symbolset, @picto, format: :svg)
    #
    #     # Now follow the redirect
    #     follow_redirect!
    #     expect(response).to have_http_status(:success)
    #     expect(response.headers['Content-Type']).to eq 'image/svg'
    #     expect(response.body).to eq @image.imagefile.read
    #   end
    # end
  end

end
