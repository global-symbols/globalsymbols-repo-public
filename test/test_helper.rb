# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'factory_bot_rails'

FactoryBot.definition_file_paths = [Rails.root.join('test/factories')]
FactoryBot.find_definitions unless FactoryBot.factories.any?

# Safety: refuse to run tests against production-like databases.
db_config = ActiveRecord::Base.connection_db_config
if db_config.database.to_s.match?(/production/i)
  abort "Refusing to run tests against production database: #{db_config.database}"
end

Dir[Rails.root.join('test/support/**/*.rb')].sort.each { |f| require f }

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods
  include WebmockStubs

  # Roll back data changes after each test (shared dev database).

  setup do
    stub_external_apis
  end

  teardown do
    next unless Rails.env.test?

    FileUtils.rm_rf(Dir[Rails.root.join('public/uploads/test/')])
  end
end

class ActionDispatch::IntegrationTest
  include FactoryBot::Syntax::Methods
  include Devise::Test::IntegrationHelpers
  include WebmockStubs
  include WebTestHelpers

  # Roll back factory data after each test (shared dev database).
  self.use_transactional_tests = true

  setup do
    stub_external_apis
  end
end