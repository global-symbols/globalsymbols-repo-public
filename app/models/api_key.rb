# frozen_string_literal: true

class APIKey < ApplicationRecord
  USER_TYPES = %w[company personal].freeze

  validates :key_digest, presence: true, uniqueness: true
  validates :user_type, presence: true, inclusion: { in: USER_TYPES }
  validates :name, presence: true
  validates :email, presence: true
  validate :email_unique_among_active_keys

  scope :active, -> { where(revoked_at: nil).where.not(activated_at: nil) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  # Build SHA256 digest of a raw key (use when creating; never persist raw key).
  def self.build_key_digest(raw_key)
    return nil if raw_key.blank?
    Digest::SHA256.hexdigest(raw_key.to_s)
  end

  # Find an active key by raw key (hashes and looks up by key_digest).
  def self.for_lookup(raw_key)
    digest = build_key_digest(raw_key)
    active.find_by(key_digest: digest) if digest.present?
  end

  def activation_expired?(window_in_hours: 2)
    return false if activation_sent_at.nil?
    activation_sent_at < window_in_hours.hours.ago
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  # At most one active key per email (case-insensitive).
  def email_unique_among_active_keys
    return if email.blank?
    return if revoked_at.present?
    normalized = email.to_s.downcase.strip
    return unless APIKey.active.where('LOWER(TRIM(email)) = ?', normalized).where.not(id: id).exists?
    errors.add(:email, :taken_active)
  end

  # Admin: revoke from Rails console only (no UI).
  # Example: APIKey.find(id).revoke!
  # Example: APIKey.active.where(email: 'user@example.com').each(&:revoke!)
  #
  # Revoke all active keys for an email (Rails console):
  # Example: APIKey.revoke_by_email!('user@example.com')
  def self.revoke_by_email!(email)
    active.where(email: email).find_each(&:revoke!)
  end
end
