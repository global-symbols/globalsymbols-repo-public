class PagesController < ApplicationController
  
  skip_before_action :authenticate_user!
  # Set @symbolsets according to User Abilities
  load_resource :symbolset, find_by: :slug, parent: false, only: [:home, :search]
  
  def home
    # Return Symbolsets with a featured_level, ordered by featured_level.
    @symbolsets = @symbolsets.where.not(featured_level: nil).order(featured_level: :asc).order(name: :asc)
  end
  
  def search
    # Trim the search query
    search_params[:query].try(:strip!)

    @search = search_params
    
    search_locale = locale.to_s.split('_').first # Serbian locales can be sr_Latn, so we take just the first letters
    @language = Language.find_by(iso639_3: @search[:language]) || Language.find_by(iso639_1: search_locale)
    @search[:language] = @language.iso639_3
    
    # If a blank query was specified, stop here.
    if search_params[:query].blank?
      @labels = []
      return
    end
    
    @labels = Label.authoritative.accessible_by(current_ability)
                   .includes(picto: [:images, :symbolset])
                   .where(
                     language_id: @language.id,
                     pictos: {
                       archived: false
                     }
                   )

    # If a Symbolset was specified, narrow the search to this Symbolset.
    @labels = @labels.joins(picto: :symbolset)
                     .where(pictos: {
                       symbolsets: {
                         slug: search_params[:symbolset]
                       }
                     }) if search_params[:symbolset].present?

    # Using Arel to build the case/when for prioritisation of results.
    # This prioritises by whole word first, then beginning of word, then in-word.
    # For instance, searching 'cat' should show, in order, 'cat', 'category', 'fat_cat'
    label_text_field = Label.arel_table[:text]
    
    order_case = Arel::Nodes::Case.new
        .when(label_text_field.eq(search_params[:query]))              .then(0)  # "cat"
        .when(label_text_field.matches("#{search_params[:query]} %"))  .then(10) # "cat bed"
        .when(label_text_field.matches("% #{search_params[:query]}"))  .then(20) # "black cat"
        .when(label_text_field.matches("% #{search_params[:query]} %")).then(30) # "black cat sleeping"
        .when(label_text_field.matches("#{search_params[:query]}%"))   .then(40) # "cathartic"
        .when(label_text_field.matches("%#{search_params[:query]}"))   .then(50) # "fatcat"
        .else(60) # no match

    @labels = @labels.where('text LIKE ?', "%#{search_params[:query]}%")
                     .order(order_case)
                     .page params[:page]
  end

  def contentful_page
    @page = contentful.entries({
                                 content_type: 'page', include: 1,
                                 'fields.slug': params[:id],
                                 limit: 1
                               }).first

    raise ActiveRecord::RecordNotFound if @page.nil?

    @og_url = request.original_url
  end
  
  def contact
  end
  
  def help_article
    begin
      # Render the help article if it exists
      render "help_#{help_params[:article]}"
    rescue ActionView::MissingTemplate
      # Otherwise, redirect to the homepage
      redirect_to '/'
      end
  end

  def help_params
    params.permit(:article)
  end

  def search_params
    params.permit(:query, :language, :symbolset)
  end

  def featured_board_sets
    @board_sets = contentful.entries({
      content_type: 'featuredBoardSet',
      order: ['fields.index', 'fields.title'],
    })
    @og_url = request.original_url
  end
end
