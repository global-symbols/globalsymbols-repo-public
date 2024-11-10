# TODO: Unused. Remove?
shared_context :doorkeeper_app_with_token do
  let(:doorkeeper_application) { FactoryBot.create(:doorkeeper_application) }
  let(:user) { FactoryBot.create(:user) }
  let(:access_token) { FactoryBot.create(:doorkeeper_token, application_id: doorkeeper_application.id, resource_owner_id: user.id) }
end