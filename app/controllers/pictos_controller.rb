class PictosController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  load_and_authorize_resource :symbolset, find_by: :slug
  load_and_authorize_resource :picto, through: :symbolset

  add_breadcrumb 'Symbolsets', :symbolsets, only: [:index, :show]

  def show
    respond_to do |format|
      # Set whether the file should be downloaded or shown in the browser
      disposition = (params['download'] && params['download'] == '1') ? :attachment : :inline

      format.html do
        add_breadcrumb(@picto.symbolset.name, symbolset_url(@picto.symbolset))
        add_breadcrumb(@picto.labels.first.text, symbolset_symbol_url(@picto.symbolset, @picto))

        @alternative_pictos = @picto.alternative_pictos.accessible_by(current_ability).page params[:page]
        @comment = Comment.new
        @surveys = Survey.accessible_by(current_ability, :manage)
      end

      format.png do
        path = png_download_path
        if path && File.exist?(path)
          send_file path, filename: download_filename('png'), disposition: disposition
        else
          handle_missing_image_file
        end
      end

      format.svg do
        path = image_download_path(extension: 'svg')
        if path && File.exist?(path)
          send_file path, filename: download_filename('svg'), disposition: disposition
        else
          handle_missing_image_file
        end
      end

      format.jpeg do
        path = image_download_path(extension: 'jpg')
        if path && File.exist?(path)
          send_file path, filename: download_filename('jpg'), disposition: disposition
        else
          handle_missing_image_file
        end
      end
    end
  end

  def new
    @picto.images.build
    @picto.labels.build(language: current_user.language)
  end

  def edit
  end

  def create
    source = Source.find_by!(slug: 'global-symbols')
    @picto.source = source
    @picto.labels.each do |label|
      label.source = source
    end

    # Check file size before building the image
    if picto_params[:images_attributes].present?
      max_size = 800.kilobytes
      image_params = picto_params[:images_attributes].values.first
      if image_params && image_params[:imagefile].present? && image_params[:imagefile].size > max_size
        flash.now[:alert] = "Image file size is too large (maximum is #{max_size / 1024}KB)."
        @picto.images.build if @picto.images.empty?
        render :new, status: :unprocessable_entity
        return
      end
    end

    if @picto.save
      redirect_to symbolset_symbol_path(id: @picto), notice: 'Symbol was successfully created.'
    else
      flash.now[:alert] = @picto.errors.full_messages.join(", ") || 'Failed to create Symbol.'
      @picto.images.build if @picto.images.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # Check file size before updating the image
    if picto_params[:images_attributes].present?
      max_size = 800.kilobytes
      image_params = picto_params[:images_attributes].values.first
      if image_params && image_params[:imagefile].present? && image_params[:imagefile].size > max_size
        flash.now[:alert] = "Image file size is too large (maximum is #{max_size / 1024}KB)."
        render :edit, status: :unprocessable_entity
        return
      end
    end

    if @picto.update(picto_params)
      redirect_to symbolset_symbol_path(id: @picto), notice: 'Symbol was successfully updated.'
    else
      flash.now[:alert] = @picto.errors.full_messages.join(", ") || 'Failed to update Symbol.'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @picto.destroy
    redirect_to symbolset_path(@symbolset), notice: 'Symbol was successfully deleted.'
  end

  def comment
    @picto = Picto.find(params[:id])
    @comment = Comment.new(comment_params)
    @comment.user = current_user
    @comment.picto = @picto
    if @comment.save
      redirect_to symbolset_symbol_path(@picto.symbolset, @picto), notice: 'Comment was successfully added.'
    else
      flash.now[:alert] = 'Failed to add comment.'
      render :show, status: :unprocessable_entity
    end
  end

  private

  def picto_params
    params.require(:picto).permit(:part_of_speech, :symbolset_id, :publisher_ref, :visibility, :archived, images_attributes: [:imagefile], labels_attributes: [:text, :text_diacritised, :description, :language_id])
  end

  def comment_params
    params.require(:comment).permit(:rating, :comment, :likert1)
  end

  def image_params
    params.permit(:download)
  end

  def download_filename(extension)
    "#{@picto.best_label_for(locale).text}_#{@picto.id}.#{extension}"
  end

  # Resolve a PNG path from either an original PNG or a converted SVG.
  # Returns nil when the source image or converted file is unavailable.
  def png_download_path
    image = @picto.images.last
    return nil unless image&.imagefile&.file.present?

    original_format = image.imagefile.file.extension.downcase.to_sym

    case original_format
    when :svg
      return nil unless File.exist?(image.imagefile.path)

      image.imagefile.recreate_versions! unless image.imagefile.svg2png.file&.exists?
      image.imagefile.svg2png.path
    when :png
      image.imagefile.path
    end
  rescue StandardError
    nil
  end

  # Resolve an SVG/JPG path when the original upload matches the requested format.
  def image_download_path(extension:)
    image = @picto.images.last
    return nil unless image&.imagefile&.file.present?
    return nil unless image.imagefile.file.extension.downcase == extension

    image.imagefile.path
  rescue StandardError
    nil
  end

  # Prefer a flash + redirect for downloads; otherwise a friendly HTML 404
  # instead of an empty image response when assets are missing (e.g. pre-prod).
  def handle_missing_image_file
    message = I18n.t('views.pictos.show.image_unavailable')

    if params[:download].to_s == '1'
      redirect_to symbolset_symbol_path(@symbolset, @picto), alert: message
    else
      flash.now[:alert] = message
      render 'errors/not_found', status: :not_found, formats: [:html], content_type: 'text/html'
    end
  end
end
