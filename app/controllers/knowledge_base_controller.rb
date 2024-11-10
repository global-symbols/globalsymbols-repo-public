class KnowledgeBaseController < ApplicationController

  # Anyone can view KB Articles
  skip_before_action :authenticate_user!

  def index
    @root_article = contentful.entries({
                                         content_type: 'kbArticle', include: 4,
                                         'fields.type': 'Root',
                                         limit: 1
                                       }).first

    @articles = @root_article.child_articles
  end

  def show
    @article = contentful.entries({
                                 content_type: 'kbArticle', include: 1,
                                 'sys.id': params[:id],
                                 limit: 1
                               }).first

    raise ActiveRecord::RecordNotFound if @article.nil?

    @root_article = contentful.entries({
                                    content_type: 'kbArticle', include: 4,
                                    'fields.type': 'Root',
                                    limit: 1
                                  }).first

    @articles = @root_article.child_articles

    @og_url = request.original_url
  end

  def search

    @query = params[:query]

    @articles = contentful.entries({
                                    content_type: 'kbArticle', include: 0,
                                    # 'fields.title[inc]': params[:query],
                                    query: params[:query]
                                  })

  end
end
