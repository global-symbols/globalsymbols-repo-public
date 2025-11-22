# frozen_string_literal: true

class TranslationNotificationMailer < ApplicationMailer
  default from: 'system@globalsymbols.com'

  # Sends notification when content translation is missing
  #
  # @param collection [String] The Directus collection name (e.g., 'articles', 'pages')
  # @param item_id [String, Integer] The ID of the item missing translation
  # @param requested_language [String] The requested language code (e.g., 'fr-FR')
  # @param fallback_language [String] The fallback language code (e.g., 'en-GB')
  # @param item_title [String, nil] Optional title of the item for better context
  def missing_translation(collection:, item_id:, requested_language:, fallback_language:, item_title: nil)
    @collection = collection
    @item_id = item_id
    @requested_language = requested_language
    @fallback_language = fallback_language
    @item_title = item_title
    @timestamp = Time.current

    # Determine recipient email - could be configurable via ENV or settings
    recipient_email = ENV['SYSTEM_ADMIN_EMAIL'] || 'admin@globalsymbols.com'

    mail(
      to: recipient_email,
      subject: "Translation Missing: #{collection.titleize} #{item_id} (#{requested_language})",
      template_name: 'missing_translation'
    )
  end

  # Sends batch notification for multiple missing translations
  #
  # @param missing_items [Array<Hash>] Array of hashes with keys: collection, item_id, requested_language, fallback_language, item_title
  def batch_missing_translations(missing_items)
    @missing_items = missing_items
    @timestamp = Time.current
    @total_count = missing_items.length

    # Group by collection for better organization
    @items_by_collection = missing_items.group_by { |item| item[:collection] }

    recipient_email = ENV['SYSTEM_ADMIN_EMAIL'] || 'admin@globalsymbols.com'

    mail(
      to: recipient_email,
      subject: "Multiple Missing Translations: #{@total_count} items across #{@items_by_collection.keys.length} collections",
      template_name: 'batch_missing_translations'
    )
  end
end
