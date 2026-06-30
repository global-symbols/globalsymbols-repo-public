# frozen_string_literal: true

require 'test_helper'

class GlobalSymbolsV1Test < ActionDispatch::IntegrationTest
  # --- Symbolsets ---

  test 'GET /api/v1/symbolsets returns published symbolsets' do
    symbolset = create(:symbolset, :published)

    get '/api/v1/symbolsets'

    assert_response :success
    body = JSON.parse(response.body)
    names = body.map { |row| row['name'] }
    assert_includes names, symbolset.name
  end

  # --- Labels ---

  test 'GET /api/v1/labels/search returns matching labels' do
    picto = published_picto_with_labels
    skip 'Requires a published picto with labels in the dev database' unless picto

    label = picto.labels.first
    query = label.text.split.first(2).join(' ')
    skip 'Label text too short to search' if query.length < 3

    get '/api/v1/labels/search', params: { query: query }

    assert_response :success
    body = JSON.parse(response.body)
    texts = body.map { |row| row['text'] }
    assert_includes texts, label.text
  end

  test 'GET /api/v1/labels/search filters by symbolset slug' do
    picto = published_picto_with_labels
    skip 'Requires a published picto with labels in the dev database' unless picto

    label = picto.labels.first
    query = label.text.split.first(2).join(' ')
    skip 'Label text too short to search' if query.length < 3

    get '/api/v1/labels/search',
        params: { query: query, symbolset: picto.symbolset.slug }

    assert_response :success
    body = JSON.parse(response.body)
    assert(body.all? { |row| row.dig('picto', 'symbolset', 'slug') == picto.symbolset.slug })
  end

  test 'GET /api/v1/labels/:id returns a single label' do
    label = accessible_authoritative_label
    skip 'Requires an accessible authoritative label in the dev database' unless label

    get "/api/v1/labels/#{label.id}"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal label.id, body['id']
    assert_equal label.text, body['text']
    assert body['picto'].is_a?(Hash)
  end

  test 'GET /api/v1/labels/:id returns not found for missing id' do
    get '/api/v1/labels/0'

    assert_response :not_found
  end

  # --- Concepts ---

  test 'GET /api/v1/concepts/suggest returns results for a query' do
    picto = Picto.joins(:symbolset, :concepts)
                 .where(symbolsets: { status: Symbolset.statuses[:published] })
                 .first
    skip 'Requires a published picto with concepts in the dev database' unless picto

    concept = picto.concepts.first
    query = concept.subject.split('_').find { |part| part.length >= 3 } || concept.subject

    get '/api/v1/concepts/suggest', params: { query: query }

    assert_response :success
    body = JSON.parse(response.body)
    subjects = body.map { |row| row['subject'] }
    assert_includes subjects, concept.subject
  end

  test 'GET /api/v1/concepts/:id returns a single concept' do
    concept = Concept.joins(pictos: :symbolset)
                     .where(symbolsets: { status: Symbolset.statuses[:published] })
                     .first
    skip 'Requires a concept linked to a published picto in the dev database' unless concept

    get "/api/v1/concepts/#{concept.id}"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal concept.id, body['id']
    assert_equal concept.subject, body['subject']
  end

  test 'GET /api/v1/concepts/:id returns not found for missing id' do
    get '/api/v1/concepts/0'

    assert_response :not_found
  end

  # --- Languages ---

  test 'GET /api/v1/languages/active returns language list' do
    get '/api/v1/languages/active'

    assert_response :success
    body = JSON.parse(response.body)
    assert body.is_a?(Array)
    assert body.any? { |row| row['iso639_1'] == 'en' || row['iso639_3'] == 'eng' }
  end

  # --- Pictos ---

  test 'GET /api/v1/pictos returns paginated pictos for a published symbolset' do
    symbolset = published_symbolset_with_visible_pictos
    skip 'Requires a published symbolset with visible pictos in the dev database' unless symbolset

    get '/api/v1/pictos', params: { symbolset: symbolset.slug }

    assert_response :success
    body = JSON.parse(response.body)
    assert body['items'].is_a?(Array)
    assert body['total'].is_a?(Integer)
    assert body['total'].positive?
    assert body['items'].any?
    assert body['items'].first['id'].is_a?(Integer)
  end

  test 'GET /api/v1/pictos supports pagination params' do
    symbolset = published_symbolset_with_visible_pictos
    skip 'Requires a published symbolset with visible pictos in the dev database' unless symbolset

    get '/api/v1/pictos', params: { symbolset: symbolset.slug, page: 1, per_page: 1 }

    assert_response :success
    body = JSON.parse(response.body)
    assert_operator body['items'].length, :<=, 1
  end

  test 'GET /api/v1/pictos supports delta mode with since timestamp' do
    symbolset = published_symbolset_with_visible_pictos
    skip 'Requires a published symbolset with visible pictos in the dev database' unless symbolset

    since = 1.year.ago.iso8601

    get '/api/v1/pictos', params: { symbolset: symbolset.slug, since: since }

    assert_response :success
    body = JSON.parse(response.body)
    assert body['items'].is_a?(Array)
    assert body['deletions'].is_a?(Array)
    assert body.key?('total')
  end

  test 'GET /api/v1/pictos returns bad request for invalid since timestamp' do
    symbolset = published_symbolset_with_visible_pictos
    skip 'Requires a published symbolset with visible pictos in the dev database' unless symbolset

    get '/api/v1/pictos', params: { symbolset: symbolset.slug, since: 'not-a-timestamp' }

    assert_response :bad_request
  end

  test 'GET /api/v1/pictos returns bad request for unknown symbolset slug' do
    get '/api/v1/pictos', params: { symbolset: 'definitely-not-a-real-symbolset-slug' }

    assert_response :bad_request
  end

  # --- User (OAuth) ---

  test 'GET /api/v1/user returns authenticated user with bearer token' do
    token = create(:doorkeeper_token, scopes: 'profile')
    user = User.find(token.resource_owner_id)

    get '/api/v1/user', headers: { 'Authorization' => "Bearer #{token.token}" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal user.id, body['id']
  end

  test 'GET /api/v1/user returns unauthorized without bearer token' do
    get '/api/v1/user'

    assert_response :unauthorized
  end

  test 'PATCH /api/v1/user updates profile fields' do
    token = create(:doorkeeper_token, scopes: 'profile')
    user = User.find(token.resource_owner_id)

    patch '/api/v1/user',
          params: { default_hair_colour: '#ABCDEF' },
          headers: { 'Authorization' => "Bearer #{token.token}" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal '#ABCDEF', body['default_hair_colour']
    assert_equal '#ABCDEF', user.reload.default_hair_colour
  end

  test 'PATCH /api/v1/user returns unauthorized without bearer token' do
    patch '/api/v1/user', params: { default_hair_colour: '#ABCDEF' }

    assert_response :unauthorized
  end

  private

  def published_picto_with_labels
    Picto.joins(:symbolset, :labels)
         .where(symbolsets: { status: Symbolset.statuses[:published] },
                archived: false,
                visibility: Picto.visibilities[:everybody])
         .first
  end

  def accessible_authoritative_label
    Label.authoritative
         .joins(picto: :symbolset)
         .where(pictos: { archived: false, visibility: Picto.visibilities[:everybody] },
                symbolsets: { status: Symbolset.statuses[:published] })
         .first
  end

  def published_symbolset_with_visible_pictos
    Symbolset.published
             .joins(:pictos)
             .where(pictos: { archived: false, visibility: Picto.visibilities[:everybody] })
             .distinct
             .first
  end
end