# frozen_string_literal: true

require 'test_helper'

class SymbolsetManagerWebTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
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

  test 'guest cannot access symbolset edit page' do
    sign_out @user

    get edit_symbolset_path(@symbolset)

    assert_redirected_to new_user_session_path(locale: :en)
  end

  test 'signed-in user without access cannot edit another users symbolset' do
    other_set = create(:symbolset, users_count: 1)

    get edit_symbolset_path(other_set)

    assert_response :unauthorized
  end

  test 'PATCH symbolset updates attributes for manager' do
    patch symbolset_path(@symbolset),
          params: { symbolset: { description: 'Updated via integration test' } }

    assert_redirected_to symbolset_path(@symbolset, locale: :en)
    assert_equal 'Updated via integration test', @symbolset.reload.description
  end
end