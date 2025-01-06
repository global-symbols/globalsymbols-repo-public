class SymbolsetsController < ApplicationController

  skip_before_action :authenticate_user!, only: [:index, :show, :download]
  load_and_authorize_resource find_by: :slug # Loads @symbolsets available to current_user by their Abilities

  add_breadcrumb 'Symbolsets', :symbolsets, only: [:index, :show]

  def index
    @symbolsets = @symbolsets.order(:name)
  end

  def show
    add_breadcrumb(@symbolset.name, symbolset_url(@symbolset))

    begin
      @language = current_user.language || Language.find_by!(iso639_1: locale.to_s.first(2))
    rescue Exception
      @language = Language.find_by(iso639_1: :en)
    end

    authoritative_sources = Source.where(authoritative: true)

    label_text_field = Label.arel_table[:text]
    @order_nulls_last = Arel::Nodes::Case.new.when(label_text_field.eq(nil)).then(1).else(0)

    @pictos = @symbolset.pictos
                        .joins("LEFT OUTER JOIN `labels` ON `labels`.`picto_id` = `pictos`.`id` AND `labels`.`source_id` IN (#{authoritative_sources.pluck(:id).join(',')}) AND (`labels`.`language_id` = #{@language.id} OR `labels`.`language_id` IS NULL)")
                        .select('pictos.*, labels.text')
                        .where(archived: false, symbolset_id: @symbolset.id)
                        .accessible_by(current_ability)
                        .includes(:images)
                        .page(params[:page])

    @labels = @symbolset.labels.unscoped.authoritative
                        .joins(:picto)
                        .where(picto: {archived: false, symbolset_id: @symbolset.id})
                        .where(language_id: @language.id)
                        .order(text: :asc)
                        .accessible_by(current_ability)
                        .includes(picto: [:images])
                        .page(params[:page])

    # @languages = Language.where(id: @symbolset.labels.select(:language_id).distinct).order(:name)
  end

  def new
  end

  def edit
  end

  def create
    # Add the current_user as a manager on the Symbolset
    @symbolset.users << current_user

    if @symbolset.save
      redirect_to @symbolset, notice: 'Symbolset was successfully created.'
    else
      logger.error "Failed to create Symbolset: #{@symbolset.errors.full_messages.join(", ")}"
      flash.now[:alert] = 'There was an error creating the Symbolset. Please check your input and try again.'
      render :new
    end
  end

  # def update
  #   redirect_to @symbolset if @symbolset.update(symbolset_params)
  # end

  def update
    if symbolset_params[:logo].present?
      @symbolset.logo.remove! # Remove the old file
      @symbolset.logo = symbolset_params[:logo] # Assign the new logo
    end

    if @symbolset.update(symbolset_params)
      redirect_to @symbolset, notice: 'Symbolset updated successfully.'
    else
      flash.now[:alert] = 'Failed to update Symbolset.'
      render :edit
    end
  end




  def review
    @pictos = @symbolset.pictos.where(archived: false).accessible_by(current_ability)
    @filter = params[:filter] || 'all'
    @pictos = @pictos.without_concepts if params[:filter] == 'without_concept'
    @pictos = @pictos.includes(:concepts, :images).page params[:page]
  end

  def translate

    @limit = 35

    # Source languages must use authoritative labels and have an ISO639_1 code.
    @source_languages = Language.unscoped
                                .joins(labels: { picto: :symbolset, source: {} })
                                .group('languages.id')
                                .where(
                                  azure_translate_supported: true,
                                  labels: {
                                    pictos: {
                                      archived: false,
                                      symbolsets: @symbolset
                                    },
                                    sources: { authoritative: true }
                                  }
                                )
                                .where.not(iso639_1: nil)
                                .select('languages.*, COUNT(labels.id) AS labels_count')

    # Destination languages must have an ISO639_1 code
    @destination_languages = Language.where(active: true, azure_translate_supported: true).where.not(iso639_1: nil)

    @source_language = Language.find_by(iso639_3: translation_get_params[:source_language]) || @source_languages.first
    @destination_language = translation_get_params[:dest_language] ? Language.find_by(iso639_3: translation_get_params[:dest_language]) : nil

    @pictos = @symbolset.pictos.where(archived: false).accessible_by(current_ability)
    @total_symbols = @pictos.count

    @sources = Label.joins(:picto).where(pictos: @pictos).group(:language_id).includes(:language)
    @sources_counts = @sources.count

    # @confirmed_source = Source.find_by(slug: 'global-symbols')

    @unapproved_suggestions = Label.unscoped.where(picto: @pictos, language: @destination_language)

    @translated_labels = Label.unscoped.joins(:source, picto: :symbolset).where(pictos: { symbolset: @symbolset }, language: @destination_language, sources: {authoritative: true})

    @pictos = @pictos.where.not(id: @translated_labels.pluck(:picto_id)).includes(:images, labels: :source).limit(@limit)

    @scripts = [
      OpenStruct.new({ name: 'Latin', key: 'Latn'}),
      OpenStruct.new({ name: 'Cyrillic', key: 'Cyrl'})
    ]


  end

  def import
    # TODO: Add to Abilities
  end

  def upload
    uploader = SymbolsetCsvUploader.new
    uploader.cache!(params[:csv_file])
    SymbolsetImporter.new(uploader.path, @symbolset)
  end

  def download
    redirect_to rails_blob_path(@symbolset.zip_bundle, disposition: :attachment)
  end

  def archive
    authorize! :manage, @symbolset
    @pictos = @symbolset.pictos
                        .where(archived: true)
                        .accessible_by(current_ability)
                        .page params[:page]
  end

  private

    def symbolset_params
      keys = [:name, :description, :publisher, :publisher_url, :licence_id, :logo]

      # Only admins are allowed to change the :status.
      keys << :status if current_user.admin?
      keys << :featured_level if current_user.admin?

      params.require(:symbolset).permit(keys)
    end

    def translation_get_params
      params.permit([:source_language, :dest_language])
    end
end
