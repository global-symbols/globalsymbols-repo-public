CarrierWave.configure do |config|

  # The maximum period for authenticated_urls is only 7 days.
  config.aws_authenticated_url_expiration = 60 * 60 * 24 * 7

  # Set custom options such as cache control to leverage browser caching.
  # You can use either a static Hash or a Proc.
  config.aws_attributes = -> { {
      expires: 1.year.from_now.httpdate,
      cache_control: "max-age=#{60 * 60 * 24 * 365}"
  } }

  config.aws_credentials  = {
      access_key_id:     ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      region:            'eu-west-2'
  }
end