# frozen_string_literal: true

class TapTopicsController < ApplicationController
  # Anyone can view this page
  skip_before_action :authenticate_user!

  def index
    @current_page = (params[:page] || 1).to_i
    @selected_category = params[:category].presence
    # Language filter (Directus code like en-GB) – used ONLY to filter which boardsets appear
    @selected_language = params[:language].presence
    @boardsets_per_page = 12

    # Display language code (driven by site locale mapping) – used for which title we show
    @language_code = directus_language_code

    begin
      all_boardsets = DirectusService.fetch_collection_with_translations(
        'boardsets',
        @language_code,
        {
          # IMPORTANT: DirectusService has article-centric default fields;
          # override them here for boardsets.
          'fields' => 'id,status,date_created,date_updated,board_low,board_high,categories.boardset_categories_id.name,categories.boardset_categories_id.id,translations.title,translations.gs_languages_code',
          'filter' => { 'status' => { '_eq' => 'published' } },
          'limit' => 1000
        },
        nil,
        true,
        { skip_translation_filter: true }
      )

      # Derive categories and languages (before filtering)
      @categories = extract_categories(all_boardsets)
      @languages = extract_languages(all_boardsets)

      if Rails.env.development? && @categories.blank? && all_boardsets.present?
        sample = all_boardsets.first
        Rails.logger.info("TapTopics categories appear empty. Sample boardset categories payload: #{sample['categories'].inspect}")
      end

      boardsets = all_boardsets

      # Apply category filter
      if @selected_category.present?
        boardsets = boardsets.select { |bs| boardset_has_category?(bs, @selected_category) }
      end

      # Apply language filter (Directus language codes)
      if @selected_language.present?
        boardsets = boardsets.select { |bs| boardset_has_language?(bs, @selected_language) }
      end

      # Sort by title in requested language (with fallback)
      boardsets = boardsets.sort_by { |bs| boardset_title(bs, @language_code).to_s.downcase }

      # Pagination
      @total_boardsets = boardsets.length
      @total_pages = (@total_boardsets.to_f / @boardsets_per_page).ceil
      start_index = (@current_page - 1) * @boardsets_per_page
      end_index = start_index + @boardsets_per_page - 1
      @boardsets = boardsets[start_index..end_index] || []

      @has_previous_page = @current_page > 1
      @has_next_page = @current_page < @total_pages
      @previous_page = @current_page - 1
      @next_page = @current_page + 1
    rescue => e
      Rails.logger.error("Failed to fetch boardsets from Directus: #{e.message}")
      Rails.logger.error("Error class: #{e.class}, Backtrace: #{e.backtrace.join("\n")}")
      @boardsets = []
      @categories = []
      @languages = []
      @total_pages = 0
      @directus_error = true
    end
  end

  private

  def extract_categories(boardsets)
    raw = boardsets.flat_map do |bs|
      categories_value = bs['categories']
      if categories_value.is_a?(Hash)
        categories_value = categories_value.values
      end
      next [] unless categories_value.is_a?(Array)

      categories_value.map do |junction|
        if junction.is_a?(Hash)
          # Typical M2M expanded shape:
          #   {"boardset_categories_id"=>{"id"=>1,"name"=>"Test"}}
          # Non-expanded shape might be:
          #   {"boardset_categories_id"=>1}
          boardset_cat = junction['boardset_categories_id']
          if boardset_cat.is_a?(Hash)
            boardset_cat['name']
          else
            junction.dig('boardset_categories_id', 'name') || junction['name']
          end
        end
      end.compact
    end

    raw.reject { |c| c.nil? || c.to_s.empty? }.map(&:to_s).uniq.sort
  end

  def extract_languages(boardsets)
    raw = boardsets.flat_map do |bs|
      translations = bs['translations']
      next [] unless translations.is_a?(Array)

      translations.map do |t|
        t.is_a?(Hash) ? t['gs_languages_code'] : nil
      end.compact
    end

    raw.reject { |c| c.nil? || c.to_s.empty? }.map(&:to_s).uniq.sort
  end

  def boardset_has_category?(boardset, category_name)
    categories_value = boardset['categories']
    if categories_value.is_a?(Hash)
      categories_value = categories_value.values
    end
    return false unless categories_value.is_a?(Array)

    categories_value.any? do |junction|
      next false unless junction.is_a?(Hash)

      boardset_cat = junction['boardset_categories_id']
      if boardset_cat.is_a?(Hash)
        boardset_cat['name'] == category_name
      else
        junction.dig('boardset_categories_id', 'name') == category_name ||
          junction['name'] == category_name
      end
    end
  end

  def boardset_has_language?(boardset, language_code)
    translations = boardset['translations']
    return false unless translations.is_a?(Array)

    translations.any? { |t| t.is_a?(Hash) && t['gs_languages_code'] == language_code }
  end

  def boardset_title(boardset, language_code)
    translation = select_translation(boardset, language_code)
    translation&.dig('title') || ''
  end

  def select_translation(boardset, language_code)
    translations = boardset['translations'] || []
    return nil unless translations.is_a?(Array)

    requested = translations.find { |t| t.is_a?(Hash) && t['gs_languages_code'] == language_code }
    fallback = translations.find { |t| t.is_a?(Hash) && t['gs_languages_code'] == DIRECTUS_DEFAULT_LANGUAGE.call }
    english = translations.find { |t| t.is_a?(Hash) && t['gs_languages_code'] == 'en-GB' }

    requested || fallback || english
  end
end


