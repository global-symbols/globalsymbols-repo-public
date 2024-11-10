class ArticlesController < ApplicationController
  
  # Anyone can view News Articles
  skip_before_action :authenticate_user!
  
  def index
    per_page = 5
    @page = params[:page].to_i
    @page = 1 if @page == 0
    
    @posts = contentful.entries({
      content_type: 'blogPost', include: 1,
      order: '-fields.publishDate',
      limit: per_page,
      skip: (@page - 1) * per_page
    })
    
    @pagination_params = {
        total_pages: (@posts.total / per_page).ceil + 1,
        current_page: @page,
        per_page: per_page
    }
  end
  
  def show
    # Extract the date and slug from the URL.
    # Format: YYYY-MM-DD-slug-of-article
    match = params[:id].match /(?<date>\d{4}-\d\d-\d\d)-(?<slug>.+)/
    
    raise ActiveRecord::RecordNotFound if match.nil?
    
    # Try to find the Article at Contentful
    @post = contentful.entries({
        content_type: 'blogPost', include: 1,
        'fields.slug': match[:slug],
        'fields.published_at[eq]': match[:date],
        limit: 1
    }).first
    
    raise ActiveRecord::RecordNotFound if @post.nil?

    @publish_date = @post.publish_date
    
    @png_heroimage_url = 'https:' + contentful.asset(@post.hero_image.id).url(format: 'png')
  end
  
  def preview
    # Try to find the Preview Article at Contentful
    @post = contentful_preview.entry(params[:id].to_s)

    raise ActiveRecord::RecordNotFound if @post.nil?

    @publish_date = @post.updated_at
    
    # Run it through the regular #show template
    render :show
  end
end
