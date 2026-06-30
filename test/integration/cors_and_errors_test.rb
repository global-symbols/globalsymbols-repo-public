# frozen_string_literal: true

require 'test_helper'

class CorsAndErrorsTest < ActionDispatch::IntegrationTest
  test 'api symbolsets includes cors headers' do
    get '/api/v1/symbolsets', headers: { 'Origin' => 'http://example.test' }

    assert_response :success
    assert_equal '*', response.headers['Access-Control-Allow-Origin']
    assert_includes response.headers['Access-Control-Allow-Methods'], 'GET'
  end

  test 'unknown api route returns not found' do
    get '/api/v1/does-not-exist'

    assert_response :not_found
  end

  test 'unknown web route returns not found' do
    get '/this-page-does-not-exist'

    assert_response :not_found
  end
end