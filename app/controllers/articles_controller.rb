class ArticlesController < ApplicationController

  # Anyone can view this page
  skip_before_action :authenticate_user!

  # Breadcrumbs
  add_breadcrumb 'news', :news, only: [:index, :show]

  def index
    # Get the Directus language code from the current Rails locale
    language_code = directus_language_code

    # Get pagination and filter parameters
    @current_page = (params[:page] || 1).to_i
    @selected_category = params[:category].presence

    # Articles per page - will be handled responsively in view with CSS
    # Default to 9 for server-side logic, responsive layout will show 6 on mobile
    @articles_per_page = 9

    # Fetch articles from Directus CMS with language-specific translation filtering
    begin
      # Fetch all articles to get categories and handle pagination/filtering
      all_articles = DirectusService.fetch_collection_with_translations('articles', language_code, {
        limit: 1000  # Fetch enough articles for pagination and category filtering
      }, nil, true, { skip_translation_filter: true }) # Skip translation filtering to show all articles

      # Show all articles - let the view handle translation fallbacks
      # Articles without translations in the requested language will show in English
      translated_articles = all_articles


      # Extract unique categories for filter links (before filtering)
      # categories is a M2M relationship: categories.article_categories_id.name
      raw_categories = translated_articles.map do |article|
        categories_value = article['categories']
        if categories_value.is_a?(Array) && categories_value.first.is_a?(Hash)
          # M2M relationship structure: [{"article_categories_id": {"id": 1, "name": "Tech"}}]
          categories_value.map { |junction| junction.dig('article_categories_id', 'name') }.compact
        else
          []
        end
      end.flatten.compact.uniq

      @categories = raw_categories.reject { |c| c.nil? || c.to_s.empty? }.map(&:to_s).uniq.sort

      # Apply category filter if selected
      if @selected_category.present?
        translated_articles = translated_articles.select do |article|
          categories_value = article['categories']
          if categories_value.is_a?(Array) && categories_value.first.is_a?(Hash)
            # Check if any of the article's categories match the selected category
            categories_value.any? { |junction| junction.dig('article_categories_id', 'name') == @selected_category }
          else
            false
          end
        end
      end

      # Sort articles by date (newest first)
      translated_articles = translated_articles.sort_by { |article| article['date_created'] ? Date.parse(article['date_created']) : Date.new(1900) }.reverse

      # Separate featured articles and select the most recent one for the hero
      featured_articles = translated_articles.select { |article| article['featured'] == true }
      @featured_article = featured_articles.first  # Use the most recent featured article for hero

      # Regular articles (exclude the hero featured article only if we're on page 1 and no category filter)
      # The featured article should still appear in category-filtered results if it matches the category
      non_featured_articles = translated_articles
      if @current_page == 1 && @selected_category.blank? && @featured_article.present?
        non_featured_articles = non_featured_articles.reject { |article| article['id'] == @featured_article['id'] }
      end

      # Implement pagination
      @total_articles = non_featured_articles.length
      @total_pages = (@total_articles.to_f / @articles_per_page).ceil
      start_index = (@current_page - 1) * @articles_per_page
      end_index = start_index + @articles_per_page - 1
      @articles = non_featured_articles[start_index..end_index] || []


      # Pagination metadata
      @has_previous_page = @current_page > 1
      @has_next_page = @current_page < @total_pages
      @previous_page = @current_page - 1
      @next_page = @current_page + 1
    rescue => e
      Rails.logger.error("Failed to fetch articles from Directus: #{e.message}")
      Rails.logger.error("Error class: #{e.class}, Backtrace: #{e.backtrace.join("\n")}")
      @articles = [] # Fallback to empty array if API fails
      @categories = []
      @total_pages = 0
      @directus_error = true
    end
  end

  def show
    # Get the Directus language code from the current Rails locale
    language_code = directus_language_code

    # Fetch article from Directus CMS by slug with language-specific translation filtering
    begin
      # Fetch articles filtered by slug
      articles = DirectusService.fetch_collection_with_translations('articles', language_code, {
        filter: { slug: { _eq: params[:slug] } }
      }, nil, true, { skip_translation_filter: true }) # Skip translation filtering to allow English-only articles

      @article = articles.first

      # Debug logging for cache inspection
      Rails.logger.info("Article show - slug: #{params[:slug]}, language: #{language_code}")
      Rails.logger.info("Article fetched: ID #{@article['id']}, title: #{@article.dig('translations', 0, 'title') rescue 'N/A'}")
      Rails.logger.info("Article content length: #{@article.dig('translations', 0, 'content')&.length rescue 'N/A'}")

      # If article is nil, it means the article doesn't exist, isn't published,
      # or has no translations in the requested, default, or English language
      if @article.nil? || @article.empty?
        Rails.logger.warn("Article with slug #{params[:slug]} not found, not published, or has no translations in #{language_code}, #{DIRECTUS_DEFAULT_LANGUAGE}, or en-GB")
        redirect_to news_path, alert: "Article not found or not available in the requested language."
        return
      end

      # Check if article has translation in requested language or fallback
      translations = @article['translations'] || []
      requested_translation = translations.find { |t| t['languages_code'] == language_code }
      fallback_translation = translations.find { |t| t['languages_code'] == DIRECTUS_DEFAULT_LANGUAGE }
      # Always try English as final fallback, even if default language is different
      english_translation = translations.find { |t| t['languages_code'] == 'en-GB' }

      # Determine which translation to use
      @translation_used = requested_translation || fallback_translation || english_translation
      @using_fallback = requested_translation.nil? && (fallback_translation.present? || english_translation.present?)

      if @translation_used.nil? || @translation_used['title'].blank?
        Rails.logger.warn("Article with slug #{params[:slug]} has no valid translation in #{language_code}, #{DIRECTUS_DEFAULT_LANGUAGE}, or en-GB")
        redirect_to news_path, alert: 'Article not found or not available in the requested language.'
        return
      end

      # Add breadcrumb for article slug
      add_breadcrumb @article['slug'] || 'article'
    rescue DirectusError => e
      Rails.logger.error("Failed to fetch article with slug #{params[:slug]} from Directus: #{e.message}")
      redirect_to news_path, alert: 'Article not found.'
      return
    end
  end
end
