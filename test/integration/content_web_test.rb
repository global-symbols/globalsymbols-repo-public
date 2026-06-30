# frozen_string_literal: true

require 'test_helper'

class ContentWebTest < ActionDispatch::IntegrationTest
  test 'symbolsets index is public' do
    published = create(:symbolset, :published)

    get symbolsets_path

    assert_response :success
    assert_match published.name, response.body
  end

  test 'published picto show page is public' do
    picto = published_picto_for_web
    skip 'Requires a published picto with labels and images in the dev database' unless picto

    get symbolset_symbol_path(picto.symbolset, picto)

    assert_response :success
    assert_match picto.labels.first.text, response.body
  end

  test 'concepts index is not available to guests' do
    get concepts_path

    assert_response :unauthorized
  end

  test 'concepts index is not available to signed-in users without manage permission' do
    sign_in create(:user)

    get concepts_path

    assert_response :unauthorized
  end

  test 'concept show page is public when concept exists' do
    concept = Concept.first
    skip 'Requires at least one concept in the dev database' unless concept

    get concept_path(concept)

    assert_response :success
  end

  test 'contact page is public' do
    get contact_path

    assert_response :success
  end

  test 'api docs page is public' do
    get '/api/docs'

    assert_response :success
  end

  test 'developer authentication form is public' do
    get developer_authentication_path

    assert_response :success
  end

  test 'POST developer authentication creates an api key request' do
    email = "factory_apikey_#{SecureRandom.hex(4)}@test.com"

    assert_difference('APIKey.count', 1) do
      post developer_authentication_path,
           params: {
             api_key: {
               user_type: 'personal',
               name: 'Test Developer',
               email: email,
               purpose: 'Integration test'
             }
           }
    end

    assert_response :success
    assert_equal email, APIKey.last.email
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test 'news index loads from Directus' do
    get news_path

    assert_response :success
  end

  test 'projects index loads from Directus' do
    get projects_path

    assert_response :success
  end

  test 'knowledge base index loads from Contentful' do
    skip 'Contentful not configured for test environment' if contentful_unconfigured?

    get knowledge_base_index_path

    assert_response :success
  end

  test 'knowledge base search accepts a query' do
    skip 'Contentful not configured for test environment' if contentful_unconfigured?

    get search_knowledge_base_index_path, params: { query: 'symbol' }

    assert_response :success
  end

  private

  def contentful_unconfigured?
    ENV['CONTENTFUL_ACCESS_TOKEN'].blank? || ENV['CONTENTFUL_SPACE_ID'].blank?
  end
end