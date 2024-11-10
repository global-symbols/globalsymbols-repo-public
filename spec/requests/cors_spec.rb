require 'rails_helper'

RSpec.shared_examples 'a CORS-enabled request' do
  it 'contains CORS headers' do
    get url, headers: { Origin: 'http://somewhere.else' }
    p response.headers
    expect(response.headers).to have_key 'Access-Control-Allow-Origin'
    expect(response.headers['Access-Control-Allow-Origin']).to eq '*'
    
    expect(response.headers).to have_key 'Access-Control-Allow-Methods'
    expect(response.headers['Access-Control-Allow-Methods']).to eq 'GET'
  end
end

RSpec.describe 'CORS', type: :request do
  context 'API Endpoints' do
    it_behaves_like 'a CORS-enabled request' do
      let(:url) { '/api/v1/symbolsets' }
    end
  end
  
  context 'Uploaded images' do
    before :each do
      @image = FactoryBot.create :image
    end

    it 'contains CORS headers' do
      get @image.imagefile.url, headers: { Origin: 'http://somewhere.else' }
      p response.headers
      expect(response.headers).to have_key 'Access-Control-Allow-Origin'
      expect(response.headers['Access-Control-Allow-Origin']).to eq '*'
  
      expect(response.headers).to have_key 'Access-Control-Allow-Methods'
      expect(response.headers['Access-Control-Allow-Methods']).to eq 'GET'
    end
  end
end
