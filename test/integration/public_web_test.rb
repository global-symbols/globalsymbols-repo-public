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
    refute_match(/#<(Label|ActiveRecord)/, response.body)
    refute_match(/we're sorry, but something went wrong/i, response.body)
  end

  test 'search page with known query does not render a raw data dump' do
    get search_path, params: { query: 'car', locale: :en }

    assert_response :success
    refute_match(/#<(Label|ActiveRecord)/, response.body)
    refute_match(/we're sorry, but something went wrong/i, response.body)
  end

  test 'home page respects locale switch' do
    get root_path, params: { locale: :nl }

    assert_response :success
    assert_match(/lang=["']nl["']/, response.body)
    assert_match(/Toegankelijkheid|Privacybeleid/, response.body)
  ensure
    I18n.locale = I18n.default_locale
  end

  test 'published symbol PNG download returns image or soft-fail redirect' do
    picto = published_picto_for_web
    skip 'Requires a published picto with labels and images in the dev database' unless picto

    get symbolset_symbol_path(picto.symbolset, picto, format: :png, download: 1)

    assert_includes [200, 302], response.status,
                    "expected 200 image or 302 soft-fail, got #{response.status}"
    refute_equal 404, response.status
    refute_equal 500, response.status
    if response.status == 200
      assert_match %r{\Aimage/}, response.media_type.to_s
    end
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

  test 'guest cannot open new symbolset form' do
    I18n.locale = I18n.default_locale
    get new_symbolset_path

    assert_redirected_to new_user_session_path(locale: I18n.default_locale)
  end

  test 'help page without article redirects to home' do
    get help_path

    assert_redirected_to root_path
  end
end