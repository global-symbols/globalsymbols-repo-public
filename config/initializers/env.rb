# Load environment variables from .env.rb file in development
# This provides a simple way to simulate environment variables without external gems
#
# Setup:
# 1. Create a .env.rb file in the Rails root directory
# 2. Add environment variables using ENV['KEY'] = 'value'
# 3. The file is automatically loaded in development and ignored by git
#
# Usage in code:
#   ENV['YOUR_VARIABLE']  # Access the variable
#
# Production:
#   Set real environment variables on your server instead of using this file

if Rails.env.development?
  env_file = Rails.root.join('.env.rb')
  if File.exist?(env_file)
    begin
      load env_file
      Rails.logger.info "Loaded environment variables from .env.rb"
    rescue => e
      Rails.logger.error "Error loading .env.rb: #{e.message}"
      raise e
    end
  else
    Rails.logger.warn ".env.rb file not found. Create it to set development environment variables."
  end
end
