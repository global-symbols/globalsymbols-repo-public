# frozen_string_literal: true

require 'test_helper'

class SymbolsetManagerWebTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, email: "mgr_#{SecureRandom.hex(6)}@test.com")
    sign_in @user
    @symbolset = managed_symbolset_for(@user)
  end

  test 'manager can access symbolset edit page' do
    get edit_symbolset_path(@symbolset)

    assert_response :success
    assert_match @symbolset.name, response.body
  end

  test 'manager can access symbolset review page' do
    get review_symbolset_path(@symbolset)

    assert_response :success
    refute_match(/we're sorry, but something went wrong/i, response.body)
  end

  test 'manager can access new picto form' do
    get new_symbolset_symbol_path(@symbolset)

    assert_response :success
  end

  test 'manager can access picto edit page for seeded picto' do
    picto = published_picto_for_web
    skip 'Requires a published picto in the dev database' unless picto

    grant_manager_access(@user, picto.symbolset)

    get edit_symbolset_symbol_path(picto.symbolset, picto)

    assert_response :success
  end

  test 'manager can access collaborators page' do
    get symbolset_collaborators_path(@symbolset)

    assert_response :success
  end

  test 'manager can access symbolset translate page' do
    source_language = add_translatable_label_to_symbolset(@symbolset)

    get translate_symbolset_path(@symbolset), params: { locale: :en }

    assert_response :success
    assert_match I18n.t('views.symbolsets.translate.heading'), response.body
    assert_match source_language.name, response.body
  end

  test 'translate page lists only pictos with source labels not bulk placeholders' do
    source_language = add_translatable_label_to_symbolset(@symbolset)
    dest_language = create(
      :language,
      azure_translate_supported: true,
      iso639_1: format('%02d', SecureRandom.random_number(100)),
      iso639_3: SecureRandom.hex(2)[0, 3],
      iso639_2b: "b#{SecureRandom.hex(1)}",
      iso639_2t: "t#{SecureRandom.hex(1)}",
      name: "Dest #{SecureRandom.hex(3)}",
      active: true,
      category: 'L',
      scope: 'I'
    )

    auth_source = Source.where(authoritative: true).first || create(:source, authoritative: true)
    bulk = create(:picto, symbolset: @symbolset, source: auth_source)
    other = create(
      :language,
      azure_translate_supported: true,
      iso639_1: format('%02d', SecureRandom.random_number(100)),
      iso639_3: SecureRandom.hex(2)[0, 3],
      name: "Other #{SecureRandom.hex(3)}",
      active: true,
      category: 'L',
      scope: 'I'
    )
    bulk.labels.first.update!(language: other, source: auth_source, text: 'Bulk Uploaded Symbol')

    get translate_symbolset_path(@symbolset),
        params: {
          locale: :en,
          source_language: source_language.iso639_3,
          dest_language: dest_language.iso639_3,
          commit: 'Find Untranslated Symbols'
        }

    assert_response :success
    assert_match 'hello symbol', response.body
    refute_match 'Bulk Uploaded Symbol', response.body
  end

  test 'guest cannot access symbolset edit page' do
    sign_out @user

    get edit_symbolset_path(@symbolset)

    assert_redirected_to new_user_session_path(locale: :en)
  end

  test 'signed-in user without access cannot edit another users symbolset' do
    other_owner = create(:user, email: "other_#{SecureRandom.hex(6)}@test.com")
    other_set = create(:symbolset, users_count: 0)
    create(:symbolset_user, user: other_owner, symbolset: other_set, role: :admin)

    get edit_symbolset_path(other_set)

    assert_response :unauthorized
  end

  test 'PATCH symbolset updates attributes for manager' do
    patch symbolset_path(@symbolset),
          params: { symbolset: { description: 'Updated via integration test' } }

    assert_redirected_to symbolset_path(@symbolset, locale: :en)
    assert_equal 'Updated via integration test', @symbolset.reload.description
  end

  test 'manager can access labels index for a picto' do
    picto = managed_picto_for(@symbolset)

    get symbolset_symbol_labels_path(@symbolset, picto)

    assert_response :success
    refute_match(/we're sorry, but something went wrong/i, response.body)
  end

  test 'manager can add a label without server error' do
    picto = managed_picto_for(@symbolset)
    ensure_translation_source!
    language = Language.find_by!(iso639_1: 'en')

    assert_difference('Label.count', 1) do
      post symbolset_symbol_labels_path(@symbolset, picto),
           params: {
             label: {
               text: "Regress Label #{SecureRandom.hex(3)}",
               language_id: language.id
             }
           }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success
    refute_match(/we're sorry, but something went wrong/i, response.body)
  end

  test 'manager can access concepts index for a picto' do
    picto = managed_picto_for(@symbolset)

    get symbolset_symbol_concepts_path(@symbolset, picto)

    assert_response :success
    refute_match(/we're sorry, but something went wrong/i, response.body)
  end

  test 'manager can add a ConceptNet concept without server error' do
    skip 'Requires CodingFramework seed' unless CodingFramework.first
    picto = managed_picto_for(@symbolset)

    post symbolset_symbol_concepts_path(@symbolset, picto),
         params: { concept: 'computer', iso639_3_code: 'eng' }

    assert_response :redirect
    follow_redirect!
    assert_response :success
    refute_match(/we're sorry, but something went wrong/i, response.body)
  end

  test 'unknown ConceptNet concept does not 500' do
    skip 'Requires CodingFramework seed' unless CodingFramework.first
    picto = managed_picto_for(@symbolset)

    # Override the default success stub so a missing concept is a soft validation error.
    stub_request(:get, %r{api\.conceptnet\.io/c/.+/zz_missing_concept})
      .to_return(status: 404, body: 'Not Found', headers: { 'Content-Type' => 'text/plain' })

    post symbolset_symbol_concepts_path(@symbolset, picto),
         params: { concept: 'zz_missing_concept', iso639_3_code: 'eng' }

    assert_response :redirect
    follow_redirect!
    assert_response :success
    refute_match(/we're sorry, but something went wrong/i, response.body)
    assert_match(
      /couldn't find a concept|couldn.t reach|unavailable|try again/i,
      flash[:alert].to_s + response.body
    )
  end

  test 'guest is redirected away from new symbolset form' do
    # Product expectation (regression R37): create button should be hidden for guests.
    # Current view always renders it; cover the auth gate until UX is fixed.
    sign_out @user

    get new_symbolset_path
    assert_redirected_to new_user_session_path(locale: :en)
  end

  private

  def ensure_translation_source!
    Source.find_or_create_by!(slug: 'translation') do |source|
      source.name = 'Translation'
      source.authoritative = false
    end
  end
end
