# frozen_string_literal: true

class TapTopicsController < ApplicationController
  # Anyone can view this page
  skip_before_action :authenticate_user!

  def index
    @current_page = (params[:page] || 1).to_i
    @selected_category = params[:category].presence
    # Language filter (Directus code like en-GB) – filters which boardsets appear (and drives title language when set)
    @selected_language = params[:language].presence
    @selected_density = params[:density].presence
    @boardsets_per_page = 12
    @language_name_by_code = {}

    # Title/display language code: if a language filter is selected, show titles in that language;
    # otherwise fall back to the site locale mapping.
    @language_code = @selected_language.presence || directus_language_code

    begin
      # Tap Topics page content (Directus pages collection), driven by site locale (not the filter language).
      page_language_code = directus_language_code

      pages = DirectusService.fetch_collection_with_translations(
        'pages',
        page_language_code,
        {
          'fields' => 'id,status,slug,translations.*',
          'filter' => { 'status' => { '_eq' => 'published' } },
          'limit' => 1000
        },
        nil,
        true,
        { skip_translation_filter: true }
      )

      @tap_topics_page = Array(pages).find { |p| p.is_a?(Hash) && p['slug'].to_s == 'tap-topics' }

      # Development fallback: allow viewing draft page content while migrating.
      if @tap_topics_page.nil? && Rails.env.development?
        all_pages = DirectusService.fetch_collection(
          'pages',
          {
            'fields' => 'id,status,slug,translations.*',
            'limit' => 1000
          }
        )
        @tap_topics_page = Array(all_pages).find { |p| p.is_a?(Hash) && p['slug'].to_s == 'tap-topics' }
      end

      if @tap_topics_page.present?
        translations = @tap_topics_page['translations'] || []
        translation_code = ->(t) { t.is_a?(Hash) ? (t['gs_languages_code'] || t['languages_code'] || t['code'] || t['locale'] || t['language']) : nil }

        requested_translation = translations.find { |t| translation_code.call(t) == page_language_code }
        fallback_translation = translations.find { |t| translation_code.call(t) == DIRECTUS_DEFAULT_LANGUAGE.call }
        english_translation = translations.find { |t| translation_code.call(t) == 'en-GB' }

        @tap_topics_translation = requested_translation || fallback_translation || english_translation
        @tap_topics_using_fallback = requested_translation.nil? && (fallback_translation.present? || english_translation.present?)
        @tap_topics_is_draft = Rails.env.development? && @tap_topics_page['status'].to_s == 'draft'
      end

      all_boardsets = DirectusService.fetch_collection_with_translations(
        'boardsets',
        @language_code,
        {
          # IMPORTANT: DirectusService has article-centric default fields;
          # override them here for boardsets.
          'fields' => 'id,status,date_created,date_updated,board_low,board_high,thumbnail,categories.boardset_categories_id.name,categories.boardset_categories_id.id,translations.title,translations.gs_languages_code',
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
      @language_name_by_code = language_name_by_code(@languages)
      @languages = @languages.sort_by do |code|
        (@language_name_by_code[code].presence || code).to_s.downcase
      end

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

      # Apply density filter (presence of low/high PDF assets)
      if @selected_density == 'low'
        boardsets = boardsets.select { |bs| bs['board_low'].present? }
      elsif @selected_density == 'high'
        boardsets = boardsets.select { |bs| bs['board_high'].present? }
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
      @language_name_by_code = {}
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

  def language_name_by_code(codes)
    return {} if codes.blank?

    languages = DirectusService.fetch_collection(
      'gs_languages',
      {
        'fields' => 'code,name',
        'filter' => { 'code' => { '_in' => codes } },
        'limit' => 1000
      }
    )

    Array(languages).each_with_object({}) do |lang, acc|
      next unless lang.is_a?(Hash)

      code = lang['code'].to_s
      name = lang['name'].to_s
      next if code.blank? || name.blank?

      acc[code] = name
    end
  rescue => e
    Rails.logger.warn("TapTopics: failed to fetch gs_languages names: #{e.message}")
    {}
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
    any_with_title = translations.find { |t| t.is_a?(Hash) && t['title'].present? }

    requested || fallback || english || any_with_title
  end
end


