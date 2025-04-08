# app/controllers/bulk_uploads_controller.rb
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
    Rails.logger.info "File name: #{params[:file].original_filename if params[:file]}" # Log the file name
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

    # Set default values for required fields
    @picto.part_of_speech = "noun" # Updated to lowercase to match enum value
    @picto.visibility = "everybody"

    source = Source.find_by(slug: 'global-symbols')
    unless source
      source = Source.create!(slug: 'global-symbols', name: 'Global Symbols')
      Rails.logger.info "Created Source with slug: 'global-symbols' for Picto creation"
    end
    @picto.source = source

    # Add a default label (required for validation)
    @picto.labels.build(
      language: current_user.language || "en",
      text: "Bulk Uploaded Symbol", # Placeholder label
      source: source
    )

    if request.format.json? && params[:file].present?
      # Save the original filename along with the image
      @picto.images.build(imagefile: params[:file], original_filename: params[:file].original_filename)
    else
      Rails.logger.info "No file present in params: #{params.inspect}"
    end

    respond_to do |format|
      if @picto.save
        Rails.logger.info "Picto saved successfully with id: #{@picto.id}"
        format.json { render json: { status: 'success', id: @picto.id }, status: :ok }
      else
        Rails.logger.info "Picto save failed: #{@picto.errors.full_messages}"
        format.json { render json: { status: 'error', errors: @picto.errors.full_messages }, status: :unprocessable_entity }
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

    # Fetch Picto records for this Symbolset with label 'Bulk Uploaded Symbol'
    @pictos = @symbolset.pictos
                        .joins(:labels)
                        .where(labels: { text: 'Bulk Uploaded Symbol' })
                        .order(created_at: :desc)
                        .limit(10)
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

    # Get the form data
    labels = params[:labels] || {}
    language_ids = params[:language_ids] || {}
    parts_of_speech = params[:part_of_speech] || {}

    # Update each Picto's label, language, and part of speech
    success = true
    ActiveRecord::Base.transaction do
      labels.each do |picto_id, new_label_text|
        picto = @symbolset.pictos.find_by(id: picto_id)
        if picto
          # Update label
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

          # Update part of speech
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
      redirect_to bulk_upload_metadata_path(symbolset_slug: @symbolset.slug), notice: "Metadata updated successfully."
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
