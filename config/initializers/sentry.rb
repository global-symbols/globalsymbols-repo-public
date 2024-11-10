Sentry.init do |config|
  config.dsn = 'https://d351e6646ae348b58a10014f5c8814b8@o234539.ingest.sentry.io/1398836'
  config.breadcrumbs_logger = [:active_support_logger]

  config.enabled_environments = [:production]

  config.async = lambda do |event, hint|
    Sentry::SendEventJob.perform_later(event, hint)
  end

  # Sample all errors
  config.sample_rate = 1.0

  # To activate performance monitoring, set one of these options.
  # We recommend adjusting the value in production:
  config.traces_sample_rate = 0.25

end