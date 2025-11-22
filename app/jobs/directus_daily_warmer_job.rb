# frozen_string_literal: true

class DirectusDailyWarmerJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting daily Directus cache warmer safety job")

    # Warm all collections that the app caches
    DirectusCollectionWarmerJob::COLLECTION_PARAMS_MAP.each_key do |collection|
      Rails.logger.info("Daily warming collection: #{collection}")

      # Warm with all locales (locales: nil means all locales)
      DirectusCollectionWarmerJob.perform_now(collection, nil)
    end

    Rails.logger.info("Completed daily Directus cache warmer safety job")
  end
end
