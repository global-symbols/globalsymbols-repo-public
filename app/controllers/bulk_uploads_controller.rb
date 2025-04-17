class BulkUploadsController < ApplicationController
  before_action :log_request

  def bulk_upload
    Rails.logger.info "Entering bulk_upload action with params: #{params.inspect}"
    Rails.logger.info "Database: #{ActiveRecord::Base.connection_db_config.database}"
    @symbolset = Symbolset.find_by(slug: params[:slug])
    if @symbolset.nil?
      Rails.logger.error "Symbolset with slug '#{params[:slug]}' not found"
      raise ActiveRecord::RecordNotFound
    end
    Rails.logger.info "Bulk Upload: Symbolset loaded with id: #{@symbolset.id}, slug: #{@symbolset.slug}"
    authorize! :bulk_upload, @symbolset
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Symbolset with slug '#{params[:slug]}' not found"
    raise
  end

  def create
    Rails.logger.info "Entering create action with params: #{params.inspect}"
    Rails.logger.info "File name: #{params[:file].original_filename if params[:file]}"
    Rails.logger.info "Database: #{ActiveRecord::Base.connection_db_config.database}"
    @symbolset = Symbolset.find_by(id: params[:symbolset_id])
    if @symbolset.nil?
      Rails.logger.error "Symbolset with id '#{params[:symbolset_id]}' not found"
      raise ActiveRecord::RecordNotFound
    end
    Rails.logger.info "Create: Symbolset loaded with id: #{@symbolset.id}, slug: #{@symbolset.slug}"
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
      language: current_user.language || "en",
      text: "Bulk Uploaded Symbol",
      source: source
    )

    if request.format.json? && params[:file].present?
      # Check file extension and reject SVGs, BMPs, and GIFs
      file_extension = File.extname(params[:file].original_filename).downcase
      if ['.svg', '.bmp', '.gif'].include?(file_extension)
        Rails.logger.warn "Rejected file #{params[:file].original_filename}: SVG, BMP, and GIF files are not allowed"
        respond_to do |format|
          format.json { render json: { status: 'error', errors: ["SVG, BMP, and GIF files are not allowed"] }, status: :unprocessable_entity, content_type: 'application/json' }
        end
        return
      end

      max_size = 800.kilobytes
      if params[:file].size > max_size
        Rails.logger.info "File '#{params[:file].original_filename}' exceeds size limit of #{max_size / 1024}KB"
        respond_to do |format|
          format.json { render json: { status: 'error', errors: ["filesize too large"] }, status: :unprocessable_entity, content_type: 'application/json' }
        end
        return
      end
      @picto.images.build(imagefile: params[:file], original_filename: params[:file].original_filename)
    else
      Rails.logger.info "No file present in params: #{params.inspect}"
      respond_to do |format|
        format.json { render json: { status: 'error', errors: ["No file provided"] }, status: :unprocessable_entity, content_type: 'application/json' }
      end
      return
    end

    respond_to do |format|
      if @picto.save
        Rails.logger.info "Picto saved successfully with id: #{@picto.id}"
        format.json { render json: { status: 'success', id: @picto.id }, status: :ok, content_type: 'application/json' }
      else
        Rails.logger.info "Picto save failed: #{@picto.errors.full_messages}"
        errors = @picto.errors.full_messages.map do |msg|
          msg.match(/is too large/) ? "filesize too large" : msg
        end
        format.json { render json: { status: 'error', errors: errors }, status: :unprocessable_entity, content_type: 'application/json' }
      end
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Symbolset with id '#{params[:symbolset_id]}' not found"
    raise
  end

  def metadata
    Rails.logger.info "Entering metadata action with params: #{params.inspect}"
    @symbolset = Symbolset.find_by(slug: params[:symbolset_slug])
    if @symbolset.nil?
      Rails.logger.error "Symbolset with slug '#{params[:symbolset_slug]}' not found"
      raise ActiveRecord::RecordNotFound
    end
    Rails.logger.info "Metadata: Symbolset loaded with id: #{@symbolset.id}, slug: #{@symbolset.slug}"
    authorize! :manage, @symbolset

    @pictos = @symbolset.pictos
                        .joins(:labels)
                        .where(labels: { text: 'Bulk Uploaded Symbol' })
                        .order(created_at: :desc)
                        .limit(40)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Symbolset with slug '#{params[:symbolset_slug]}' not found"
    raise
  end

  def update_labels
    Rails.logger.info "Entering update_labels action with params: #{params.inspect}"
    @symbolset = Symbolset.find_by(slug: params[:symbolset_slug])
    if @symbolset.nil?
      Rails.logger.error "Symbolset with slug '#{params[:symbolset_slug]}' not found"
      raise ActiveRecord::RecordNotFound
    end
    authorize! :manage, @symbolset

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
        redirect_to symbolset_path(@symbolset.slug), notice: "All metadata updated, returning to Symbolset page."
      else
        redirect_to bulk_upload_metadata_path(symbolset_slug: @symbolset.slug), notice: "Metadata updated successfully."
      end
    else
      redirect_to bulk_upload_metadata_path(symbolset_slug: @symbolset.slug), alert: "Failed to update metadata. Please try again."
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Symbolset with slug '#{params[:symbolset_slug]}' not found"
    raise
  end

  private
  def log_request
    Rails.logger.info "Request: #{request.method} #{request.fullpath}"
    Rails.logger.info "Params: #{params.inspect}"
  end
end
