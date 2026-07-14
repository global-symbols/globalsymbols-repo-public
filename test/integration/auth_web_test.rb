# frozen_string_literal: true

require 'test_helper'

class AuthWebTest < ActionDispatch::IntegrationTest
  test 'protected routes redirect guests to sign in' do
    get new_symbolset_path

    assert_redirected_to new_user_session_path(locale: :en)
  end

  test 'sign in page is reachable without authentication' do
    get new_user_session_path

    assert_response :success
    assert_match(/sign in/i, response.body)
  end

  test 'signed-in user can access new symbolset form' do
    user = create(:user)
    sign_in user

    get new_symbolset_path

    assert_response :success
  end

  test 'sign out returns guest to unauthenticated state' do
    user = create(:user)
    sign_in user
    sign_out user

    get new_symbolset_path

    assert_redirected_to new_user_session_path(locale: :en)
  end

  test 'POST sign in with valid credentials redirects away from login' do
    user = create(:user, password: 'password')

    post user_session_path, params: { user: { email: user.email, password: 'password' } }

    assert_redirected_to root_path(locale: :en)
    follow_redirect!
    assert_response :success
  end

  test 'POST sign in with invalid credentials re-renders login' do
    user = create(:user, password: 'password')

    post user_session_path, params: { user: { email: user.email, password: 'wrong-password' } }

    assert_response :success
    assert_match(/invalid/i, response.body)
  end

  test 'password reset form is reachable' do
    get new_user_password_path

    assert_response :success
    refute_match(/we're sorry, but something went wrong/i, response.body)
  end

  test 'POST password reset with valid email does not error and sends mail' do
    user = create(:user, password: 'password')
    ActionMailer::Base.deliveries.clear

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      post user_password_path, params: { user: { email: user.email } }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success
    refute_match(/we're sorry, but something went wrong/i, response.body)
  end

  test 'sign up page is reachable' do
    get new_user_registration_path

    assert_response :success
    assert_match(/sign up|create account|register/i, response.body)
  end
end