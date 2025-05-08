source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '>= 2.5.1'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '6.1.3.2'
# Use mysql as the database for Active Record
#gem 'mysql2', '>= 0.4.4', '< 0.6.0'
gem 'mysql2', '0.5.3'
# Use Puma as the app server
gem 'puma', '~> 5.2.2'
# Use SCSS for stylesheets
gem 'sass-rails'
# Use Uglifier as compressor for JavaScript assets
# gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'terser'

gem 'coffee-rails'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use ActiveStorage variant

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

gem 'redis', '~> 4.8'
gem 'sidekiq', '~> 6.5'
gem 'sidekiq-unique-jobs', '~> 7.1'

gem 'rack-cors', require: 'rack/cors'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

gem 'devise' # User authentication
gem 'cancancan', '3.2.1'

#gem 'doorkeeper' # OAuth2
gem 'doorkeeper', '5.4.0'

gem 'doorkeeper-openid_connect' # Layer to support OIDC authentication.

#gem 'activerecord-import'
gem 'activerecord-import', '1.0.8'

gem 'strip_attributes'

# Somethings prevents versions > 3.1.7 from parsing ConceptNet JSON correctly.
# Upgrade at your peril.
gem 'json-ld', '3.1.7' # JSON Linked Data (for ConceptNet)

gem 'carrierwave', '~> 2.0' # File uploader and sanitiser
gem 'carrierwave-aws'
gem 'carrierwave-base64'

# gem 'smarter_csv', '~> 1.2', '>= 1.2.3' # Parses, validates and converts CSVs to hash
gem 'smarter_csv', :git => 'https://github.com/tilo/smarter_csv.git'# Parses, validates and converts CSVs to hash

gem 'mini_magick', '~> 4.11' # Image manipulation, resizing, conversion, etc. Requires the system package Imagemagick to be installed.
# gem 'rmagick', '~> 2.15', '>= 2.15.4'

gem 'rubyzip', '~> 2.3' # Zip file creation and manipulation

#gem 'default_value_for', '~> 3.0.2' # Would be nice to use, but incompatible in ActiveRecord 5.2, and development appears sluggish.

gem 'sentry-ruby'
gem 'sentry-rails'

gem 'oauth'

# Front-end Gems
gem 'bootstrap', '~> 4.1'
gem 'bootstrap_form', '4.5.0'
#gem 'haml'
gem 'haml', '5.2.1'

gem 'haml-rails', '~> 2.0'
gem 'jquery-rails'
gem 'clipboard-rails'
gem 'meta-tags'     # Generates page titles, meta tags and OG data
gem 'breadcrumble'  # Generates rich data breadcrumbs
gem 'redcarpet'     # Converts Markdown to HTML
gem 'font-awesome-sass', '~> 5.13'

# Exports XLSX
# Requires rubyzip.
gem 'caxlsx'
gem 'caxlsx_rails'

# Sorts tables.
# Recommends also adding moment.js, but not used. See https://github.com/DuroSoft/rails_bootstrap_sortable
gem 'rails_bootstrap_sortable'

gem 'kaminari', '~> 1.2' # Pagination
gem 'friendly_id', '~> 5.1' # Slugs in URLs

gem 'contentful'
gem 'rich_text_renderer'

# PDF Generation
gem 'prawn'
gem 'prawn-table'
gem 'prawn-svg'
gem 'pdf-core'      # Provided by Prawn, but required so we have a list of paper sizes
gem 'svg_optimizer' # Tidies up SVG files. Complex SVGs cause problems with prawn-svg.

# Automatic Translation Service
gem 'bing_translator', '~> 6.1'

# HTTP requests
gem 'faraday'

# API Gems
# gem 'grape'
gem 'grape', '1.5.3'
gem 'grape-cancan'
gem 'grape-entity'
gem 'grape-swagger'
gem 'grape-swagger-entity'
gem 'grape-swagger-rails'

# The Wine Bouncer published on RubyGems, currently v1.0.4, requires grape < 1.3, so using git for now.
# Check https://rubygems.org/gems/wine_bouncer
gem 'wine_bouncer', github: 'antek-drzewiecki/wine_bouncer', ref: 'c82b88f'

# Task scheduler
gem 'whenever', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
 # gem 'rspec-rails'
gem 'rspec-core', '3.10.1'
gem 'rspec-expectations', '3.10.1'
gem 'rspec-mocks', '3.10.2'
gem 'rspec-rails', '5.0.1'

 gem 'rails-controller-testing'
  gem 'factory_bot_rails', '~> 6.1.0', '>= 4.8.2', require: false

  gem 'wdm', '>= 0.1.0' if Gem.win_platform?
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'

  gem 'rack-mini-profiler'
  gem 'stackprof'

  gem 'rails_real_favicon'

  gem 'listen'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15', '< 4.0'
  gem 'selenium-webdriver'
  # Easy installation and use of webdrivers to run system tests with Selenium
  gem 'webdrivers'

  gem 'webmock', '< 4.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]


# AWS SDK
gem 'aws-sdk-core', '3.113.0'
gem 'aws-sdk-kms', '1.43.0'
gem 'aws-sdk-s3', '1.91.0'
