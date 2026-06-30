# frozen_string_literal: true

require 'webmock/minitest'

WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [
    /sentry\.io/,
    /amazonaws\.com/,
    /cms\.gs-test\.co\.uk/,
    /cms\.globalsymbols/,
    /api\.contentful\.com/,
    /cdn\.contentful\.com/
  ]
)

module WebmockStubs
  def stub_external_apis
    stub_request(:get, 'api.conceptnet.io/ld/conceptnet5.6/context.ld.json')
      .to_return(body: File.read(Rails.root.join('test/fixtures/coding_framework.conceptnet.context.txt')))

    stub_request(:get, Addressable::Template.new('api.conceptnet.io/c/{language}/{subject}'))
      .to_return(body: File.read(Rails.root.join('test/fixtures/coding_framework.conceptnet.api.success.txt')))

    stub_request(:get, Addressable::Template.new('api.conceptnet.io/c/{language}/fail_{subject}'))
      .to_return(body: File.read(Rails.root.join('test/fixtures/coding_framework.conceptnet.api.failure.txt')))

    stub_request(:get, Addressable::Template.new('https://ocha.un/icons.zip'))
      .to_return(
        body: File.read(Rails.root.join('test/fixtures/symbolset_sync_sources/ocha-sample-16-icons-and-font.zip')),
        status: 200
      )

    stub_request(:get, Addressable::Template.new('https://ocha.un/icons-with-airport-updated.zip'))
      .to_return(
        body: File.read(Rails.root.join('test/fixtures/symbolset_sync_sources/ocha-sample-16-icons-and-font-with-airport-updated.zip')),
        status: 200
      )

    stub_request(:get, Addressable::Template.new('https://github.com/hfg-gmuend/openmoji/archive/{version}.zip'))
      .to_return(
        body: File.read(Rails.root.join('test/fixtures/symbolset_sources/openmoji/12.3.0.zip')),
        status: 200
      )

    noun_project_body = File.read(Rails.root.join('test/fixtures/api/noun_project_icons_response.txt'))
    noun_project_json = noun_project_body.include?("\r\n\r\n") ? noun_project_body.split("\r\n\r\n", 2).last : noun_project_body.split("\n\n", 2).last
    stub_request(:get, Addressable::Template.new('https://api.thenounproject.com/icons/{query}'))
      .to_return(body: noun_project_json, headers: { 'Content-Type' => 'application/json' })
  end
end