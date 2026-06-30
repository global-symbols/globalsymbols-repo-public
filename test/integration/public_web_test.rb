# frozen_string_literal: true

require 'test_helper'

class PublicWebTest < ActionDispatch::IntegrationTest
  test 'home page returns success' do
    get root_path
    assert_response :success
  end

  test 'search page returns success' do
    picto = Picto.joins(:symbolset, :labels)
                 .where(symbolsets: { status: Symbolset.statuses[:published] })
                 .first
    skip 'Requires a published picto with labels in the dev database' unless picto

    label_text = picto.labels.first.text

    get search_path, params: { query: label_text }

    assert_response :success
    assert_match label_text, response.body
  end

  test 'published symbolset page returns success' do
    symbolset = create(:symbolset, :published)

    get symbolset_path(symbolset)

    assert_response :success
    assert_match symbolset.name, response.body
  end

  test 'about page returns success' do
    get about_path

    assert_response :success
  end

  test 'help page without article redirects to home' do
    get help_path

    assert_redirected_to root_path
  end
end