# frozen_string_literal: true

require 'test_helper'

class SurveyEditorWebTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, email: "survey_#{SecureRandom.hex(6)}@test.com")
    sign_in @user
    @symbolset = managed_symbolset_for(@user)
    @survey = create(:survey, symbolset: @symbolset, pictos_count: 0)
    @survey.pictos << managed_picto_for(@symbolset)
  end

  test 'manager can open surveys index without exception or raw code leak' do
    get symbolset_surveys_path(@symbolset)

    assert_response :success
    refute_exception_or_raw_code!
    assert_match(/survey/i, response.body)
  end

  test 'manager can open new survey form without exception or raw code leak' do
    get new_symbolset_survey_path(@symbolset)

    assert_response :success
    refute_exception_or_raw_code!
  end

  test 'manager can open survey editor show without exception or raw code leak' do
    get symbolset_survey_path(@symbolset, @survey)

    assert_response :success
    refute_exception_or_raw_code!
    assert_match @survey.name.to_s, response.body
  end

  test 'public survey participant page does not leak source code' do
    sign_out @user
    @survey.update!(status: :collecting_feedback)

    get survey_path(@survey)

    assert_includes [200, 302], response.status
    refute_exception_or_raw_code! if response.status == 200
  end

  private

  def refute_exception_or_raw_code!
    body = response.body.to_s
    refute_match(/we're sorry, but something went wrong/i, body)
    refute_includes body, '<%='
    refute_includes body, '# frozen_string_literal'
    refute_match(/ActionView::Template::Error|SyntaxError/, body)
  end
end
