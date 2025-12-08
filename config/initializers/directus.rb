# Directus configuration – 100% ENV-driven, no hardcodes
directus_url        = ENV['DIRECTUS_URL']
directus_token      = ENV['DIRECTUS_TOKEN_CMS']
directus_webhook_secret = ENV['DIRECTUS_WEBHOOK_SECRET']

missing = []
missing << 'DIRECTUS_URL'   if directus_url.blank?
missing << 'DIRECTUS_TOKEN' if directus_token.blank?

if missing.any?
  if Rails.env.development?
    # In development, allow missing env vars - they may be loaded later by env.rb
    Rails.logger.warn "Directus configuration incomplete. Missing: #{missing.join(', ')}. Will check again after env.rb loads."
    DIRECTUS_URL             = nil
    DIRECTUS_TOKEN_CMS       = nil
    DIRECTUS_WEBHOOK_SECRET  = nil
  else
  raise <<~ERROR
    Directus configuration is incomplete.
    Please set the following environment variables:

      DIRECTUS_URL   = <your-directus-url>
      DIRECTUS_TOKEN = <your-static-token>

    Missing: #{missing.join(', ')}
  ERROR
end
else
DIRECTUS_URL             = directus_url
  DIRECTUS_TOKEN_CMS       = directus_token
DIRECTUS_WEBHOOK_SECRET  = directus_webhook_secret

DIRECTUS_URL.freeze
  DIRECTUS_TOKEN_CMS.freeze
DIRECTUS_WEBHOOK_SECRET.freeze
end