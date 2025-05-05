class SymbolsetsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show, :download]
  load_and_authorize_resource find_by: :slug
  before_action :log_request, only: [:bulk_upload, :bulk_create, :metadata, :update_labels]

  add_breadcrumb 'Symbolsets', :symbolsets, only: [:index, :show]

  def index
    @symbolsets = @symbolsets.order(:name)
  end

  def show
    if @symbolset.nil?
      Rails.logger.error "Symbolset not loaded for slug: #{params[:slug]}"
      flash[:alert] = "Symbolset not found or you lack permission to view it."
      redirect_to symbolsets_path and return
    end

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

  def bulk_upload
    Rails.logger.info "Entering bulk_upload action with params: #{params.inspect}"
    Rails.logger.info "Database: #{ActiveRecord::Base.connection_db_config.database}"
    Rails.logger.info "Bulk Upload: Symbolset loaded with id: #{@symbolset.id}, slug: #{@symbolset.slug}"
    authorize! :bulk_upload, @symbolset
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Symbolset with slug '#{params[:slug]}' not found"
    raise
  end

  def bulk_create
    Rails.logger.info "Entering bulk_create action with params: #{params.inspect}"
    Rails.logger.info "File name: #{params[:file].original_filename if params[:file]}"
    Rails.logger.info "Database: #{ActiveRecord::Base.connection_db_config.database}"
    if @symbolset.nil?
      Rails.logger.error "Symbolset with id '#{params[:symbolset_id]}' not found"
      raise ActiveRecord::RecordNotFound
    end
    Rails.logger.info "Bulk Create: Symbolset loaded with id: #{@symbolset.id}, slug: #{@symbolset.slug}"
    authorize! :create, @symbolset

    @picto = @symbolset.pictos.build
    authorize! :create, @picto

    @picto.part_of_speech = "noun"
    @picto.visibility = "everybody"

    source = Source.find_by(slug: 'global-symbols')
    unless source
      source = Source.create!(slug: 'global-symbols', name: 'Global Symbols')
      Rails.logger.info "Created Source with slug: 'global-symbols' for Picto creation"
    end
    @picto.source = source

    @picto.labels.build(
      language: current_user.language || Language.find_by(iso639_1: 'en'),
      text: "Bulk Uploaded Symbol",
      source: source
    )

    if request.format.json? && params[:file].present?
      file_extension = File.extname(params[:file].original_filename).downcase
      if ['.bmp', '.gif'].include?(file_extension)
        Rails.logger.warn "Rejected file #{params[:file].original_filename}: BMP and GIF files are not allowed"
        respond_to do |format|
          format.json { render json: { status: 'error', errors: ["BMP and GIF files are not allowed"] }, status: :unprocessable_entity }
        end
        return
      end

      max_size = 800.kilobytes
      if params[:file].size > max_size
        Rails.logger.info "File '#{params[:file].original_filename}' exceeds size limit of #{max_size / 1024}KB"
        respond_to do |format|
          format.json { render json: { status: 'error', errors: ["filesize too large"] }, status: :unprocessable_entity }
        end
        return
      end
      @picto.images.build(imagefile: params[:file], original_filename: params[:file].original_filename)
    else
      Rails.logger.info "No file present in params: #{params.inspect}"
      respond_to do |format|
        format.json { render json: { status: 'error', errors: ["No file provided"] }, status: :unprocessable_entity }
      end
      return
    end

    respond_to do |format|
      if @picto.save
        Rails.logger.info "Picto saved successfully with id: #{@picto.id}"
        if @picto.images.first.imagefile.file.extension.downcase == 'svg'
          SvgToPngConversionJob.perform_later(@picto.images.first.id)
        end
        format.json { render json: { status: 'success', id: @picto.id, image_id: @picto.images.first.id }, status: :ok }
      else
        Rails.logger.info "Picto save failed: #{@picto.errors.full_messages}"
        errors = @picto.errors.full_messages.map do |msg|
          msg.match(/is too large/) ? "filesize too large" : msg
        end
        format.json { render json: { status: 'error', errors: errors }, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Symbolset with id '#{params[:symbolset_id]}' not found"
    raise
  end

  def image_status
    image = Image.find(params[:image_id])
    render json: { status: image.status }
  end

  def metadata
  Rails.logger.info "Entering metadata action with params: #{params.inspect}"
  Rails.logger.info "Metadata: Symbolset loaded with id: #{@symbolset.id}, slug: #{@symbolset.slug}"
  authorize! :metadata, @symbolset

  @pictos = @symbolset.pictos
                      .joins(:labels)
                      .where(labels: { text: 'Bulk Uploaded Symbol' })
                      .joins("LEFT OUTER JOIN images ON images.picto_id = pictos.id")
                      .where(
                        "images.id IS NULL OR " + # No image
                        "images.original_filename NOT LIKE '%.svg' OR " + # Not an SVG
                        "(images.original_filename LIKE '%.svg' AND images.status = 'completed')" # SVG with completed status
                      )
                      .order(created_at: :desc)
                      .limit(40)
                      .includes(:images, labels: :language)

rescue ActiveRecord::RecordNotFound
  Rails.logger.error "Symbolset with slug '#{params[:slug]}' not found"
  raise
end

  def update_labels
    Rails.logger.info "Entering update_labels action with params: #{params.inspect}"
    authorize! :metadata, @symbolset

    labels = params[:labels] || {}
    language_ids = params[:language_ids] || {}
    parts_of_speech = params[:part_of_speech] || {}

    success = true
    ActiveRecord::Base.transaction do
      labels.each do |picto_id, new_label_text|
        picto = @symbolset.pictos.find_by(id: picto_id)
        if picto
          label = picto.labels.first
          if label
            label.text = new_label_text
            label.language_id = language_ids[picto_id] if language_ids[picto_id].present?
            unless label.save
              success = false
              Rails.logger.error "Failed to update label for Picto #{picto_id}: #{label.errors.full_messages}"
              raise ActiveRecord::Rollback
            end
          else
            Rails.logger.error "No label found for Picto #{picto_id}"
            success = false
            raise ActiveRecord::Rollback
          end

          if parts_of_speech[picto_id].present?
            picto.part_of_speech = parts_of_speech[picto_id]
            unless picto.save
              success = false
              Rails.logger.error "Failed to update Picto #{picto_id}: #{picto.errors.full_messages}"
              raise ActiveRecord::Rollback
            end
          end
        else
          Rails.logger.error "Picto #{picto_id} not found for Symbolset #{@symbolset.id}"
          success = false
          raise ActiveRecord::Rollback
        end
      end
    end

    if success
      remaining_bulk_symbols = @symbolset.pictos
                                        .joins(:labels)
                                        .where(labels: { text: 'Bulk Uploaded Symbol' })
                                        .count
      if remaining_bulk_symbols.zero?
        redirect_to symbolset_path(@symbolset), notice: "All metadata updated, returning to Symbolset page."
      else
        redirect_to metadata_symbolset_path(@symbolset), notice: "Metadata updated successfully."
      end
    else
      redirect_to metadata_symbolset_path(@symbolset), alert: "Failed to update metadata. Please try again."
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Symbolset with slug '#{params[:slug]}' not found"
    raise
  end

  private

    def symbolset_params
      keys = [:name, :description, :publisher, :publisher_url, :licence_id, :logo]
      keys << :status if current_user.admin?
      keys << :featured_level if current_user.admin?
      params.require(:symbolset).permit(keys)
    end

    def translation_get_params
      params.permit([:source_language, :dest_language])
    end

    def log_request
      Rails.logger.info "Request: #{request.method} #{request.fullpath}"
      Rails.logger.info "Params: #{params.inspect}"
    end
end
