module ArticlesHelper
  def redcarpet(renderer = Redcarpet::Render::HTML)
    Redcarpet::Markdown.new(renderer, filter_html: true)
  end

  # Copy of Kaiminari::Helpers::HelperMethods.paginate
  # Kaiminari is tied to ActiveRecord. This helper allows it to use Contentful data.
  # @param [Object] scope   The Contentful data to be paginated. Usually the result of a contentful.entries query.
  # @param [Hash] options   must implement this format: { total_pages: 10, current_page: 1, per_page: 2 }
  def paginate_articles(scope, paginator_class: Kaminari::Helpers::Paginator, template: nil, **options)
    # options[:total_pages] ||= scope.total_pages
    options.reverse_merge! remote: false
  
    paginator = paginator_class.new (template || self), **options
    paginator.to_s
  end
  
  def slug_for(post)
    date = post.publish_date || post.updated_at
    "#{date.strftime('%Y-%m-%d')}-#{post.slug}"
  end

  # Generate slug from Directus article date and title
  # Format: YYYY-MM-DD-slugified-title
  def generate_article_slug(article)
    return nil if article.nil?

    # Get the date (use date_created)
    date = article['date_created']
    return nil if date.nil?

    # Parse the date and format as YYYY-MM-DD
    begin
      date_part = Date.parse(date).strftime('%Y-%m-%d')
    rescue ArgumentError
      return nil
    end

    # Get the title from the default language translation
    translations = article['translations'] || []
    default_translation = translations.find { |t| t['languages_code'] == 'en-GB' } # Assuming en-GB is default
    title = default_translation&.dig('title') || article['title'] || 'untitled'

    # Slugify the title: lowercase, replace spaces/special chars with hyphens
    title_slug = title.downcase
                     .gsub(/[^\w\s-]/, '')  # Remove special characters except spaces and hyphens
                     .gsub(/\s+/, '-')      # Replace spaces with hyphens
                     .gsub(/-+/, '-')       # Replace multiple hyphens with single hyphen
                     .gsub(/^-|-$/, '')     # Remove leading/trailing hyphens

    # Combine date and title slug
    "#{date_part}-#{title_slug}"
  end
end
