# frozen_string_literal: true

class DirectusDailyWarmerJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting daily Directus cache warmer safety job")

    # Warm all active collections from database
    DirectusCachedCollection.active.ordered_by_priority.each do |collection_record|
      collection = collection_record.name
      Rails.logger.info("Daily warming collection: #{collection}")

      # Warm with all locales (locales: nil means all locales)
      DirectusCollectionWarmerJob.perform_now(collection, nil)
    end

    Rails.logger.info("Completed daily Directus cache warmer safety job")
  end
end
