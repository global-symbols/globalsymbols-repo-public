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
    # NOTE: This action name is historic; data now comes from Directus (collection: pages)
    slug = (params[:id].presence || 'about').to_s
    language_code = directus_language_code

    # Fetch all published pages once per locale (cache-friendly), then select by slug.
    pages = DirectusService.fetch_collection_with_translations(
      'pages',
      language_code,
      {
        # Use translations.* to support different translation schema variants
        # (e.g. gs_languages_code vs languages_code) without breaking the request.
        'fields' => 'id,status,slug,translations.*',
        'filter' => { 'status' => { '_eq' => 'published' } },
        'limit' => 1000
      },
      nil,
      true,
      { skip_translation_filter: true }
    )

    @page = Array(pages).find { |p| p.is_a?(Hash) && p['slug'].to_s == slug }

    # Development fallback: allow viewing draft pages while content is being migrated.
    # Production remains strictly "published" only.
    if @page.nil? && Rails.env.development?
      all_pages = DirectusService.fetch_collection(
        'pages',
        {
          'fields' => 'id,status,slug,translations.*',
          'limit' => 1000
        }
      )
      @page = Array(all_pages).find { |p| p.is_a?(Hash) && p['slug'].to_s == slug }
    end

    raise ActiveRecord::RecordNotFound if @page.nil?

    # Used by the view to indicate draft status in development.
    @is_draft = Rails.env.development? && @page.is_a?(Hash) && @page['status'].to_s == 'draft'

    translations = @page['translations'] || []
    translation_code = ->(t) { t.is_a?(Hash) ? (t['gs_languages_code'] || t['languages_code'] || t['code'] || t['locale'] || t['language']) : nil }

    requested_translation = translations.find { |t| translation_code.call(t) == language_code }
    fallback_translation = translations.find { |t| translation_code.call(t) == DIRECTUS_DEFAULT_LANGUAGE.call }
    english_translation = translations.find { |t| translation_code.call(t) == 'en-GB' }

    @translation_used = requested_translation || fallback_translation || english_translation
    raise ActiveRecord::RecordNotFound if @translation_used.nil?

    @using_fallback = requested_translation.nil? && (fallback_translation.present? || english_translation.present?)
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
