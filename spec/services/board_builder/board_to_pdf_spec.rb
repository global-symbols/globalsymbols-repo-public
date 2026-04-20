require 'rails_helper'

RSpec.describe BoardBuilder::BoardToPdf do
  describe '.fetch_response_with_redirects' do
    it 'follows redirects to the final response' do
      stub_request(:get, 'https://example.com/uploads/image.png')
        .to_return(status: 302, headers: { 'Location' => '/symbols/image.png' })

      stub_request(:get, 'https://example.com/symbols/image.png')
        .to_return(status: 200, body: 'png-data', headers: { 'Content-Type' => 'image/png' })

      response = described_class.fetch_response_with_redirects(
        :get,
        'https://example.com/uploads/image.png',
        timeout: 5,
        open_timeout: 2
      )

      expect(response.status).to eq(200)
      expect(response.body).to eq('png-data')
      expect(response.headers['content-type']).to eq('image/png')
    end

    it 'raises after exceeding the redirect limit' do
      stub_request(:get, 'https://example.com/one')
        .to_return(status: 302, headers: { 'Location' => '/two' })

      stub_request(:get, 'https://example.com/two')
        .to_return(status: 302, headers: { 'Location' => '/three' })

      stub_request(:get, 'https://example.com/three')
        .to_return(status: 302, headers: { 'Location' => '/four' })

      stub_request(:get, 'https://example.com/four')
        .to_return(status: 302, headers: { 'Location' => '/five' })

      expect do
        described_class.fetch_response_with_redirects(
          :get,
          'https://example.com/one',
          timeout: 5,
          open_timeout: 2
        )
      end.to raise_error(Faraday::Error, /Too many redirects/)
    end
  end
end
