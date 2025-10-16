require 'base64'

module BoardBuilder::V1::SharedHelpers
  extend Grape::API::Helpers

  params :expand do
    optional :expand, type: Array[String], desc: 'Space-separated of fields to expand.', default: [], coerce_with: ->(val) { val.split(/\s+/) }
  end

  # def current_user
  #   @current_user ||= User.authorize!(env)
  # end

  def current_user
    resource_owner
  end

  def authenticate!
    error!({ error: "Unauthorized",
             code: 401,
             with: V1::Entities::Error},
           401) unless current_user
  end

  # Computes a stable, pseudonymized hash for the authenticated user id.
  # Uses HMAC-SHA256 with an application secret so it cannot be reversed or forged by clients.
  def current_user_id_hash
    # Prefer a dedicated secret if configured
    # Hardcoded fallback (for dev only) to avoid nil hashes when secrets are not set.
    dev_fallback_secret = ''
    secret = ENV['AI_ANALYTICS_HASH_SECRET'].presence || dev_fallback_secret
    return nil if secret.blank?

    # Determine an identifier to hash using server-side sources only:
    # 1) Doorkeeper token lookup for resource_owner_id
    # 2) Fallback to current_user.id if present
    ro_id = resource_owner_id_from_tokens
    user_id_str = ro_id.present? ? ro_id.to_s : (current_user&.id&.to_s)

    return nil if user_id_str.blank?

    digest_bytes = OpenSSL::HMAC.digest('SHA256', secret, user_id_str)
    Base64.urlsafe_encode64(digest_bytes, padding: false)
  end

  # Extract raw bearer token from Authorization header
  def bearer_token
    auth = headers['Authorization'] || headers['authorization']
    return nil if auth.blank?
    scheme, token = auth.to_s.split(' ', 2)
    return nil unless scheme&.casecmp('Bearer')&.zero?
    token.presence
  end

  # Try to resolve resource_owner_id using Doorkeeper token objects or DB
  def resource_owner_id_from_tokens
    # Prefer doorkeeper_token helper if available
    if respond_to?(:doorkeeper_token) && doorkeeper_token
      ro_id = doorkeeper_token.resource_owner_id
      return ro_id if ro_id.present?
      # If token is opaque and persisted, attempt DB lookup by token string
      begin
        token_str = doorkeeper_token.token if doorkeeper_token.respond_to?(:token)
        token_str ||= bearer_token
        if token_str.present? && defined?(Doorkeeper::AccessToken)
          db_token = Doorkeeper::AccessToken.by_token(token_str)
          return db_token.resource_owner_id if db_token&.resource_owner_id.present?
        end
      rescue StandardError
        # ignore
      end
    else
      # As a last resort, try DB lookup with raw bearer token
      token_str = bearer_token
      if token_str.present? && defined?(Doorkeeper::AccessToken)
        begin
          db_token = Doorkeeper::AccessToken.by_token(token_str)
          return db_token.resource_owner_id if db_token&.resource_owner_id.present?
        rescue StandardError
          # ignore
        end
      end
    end
    nil
  end

end