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
end
