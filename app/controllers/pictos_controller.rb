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
        original_format = @picto.images.last.imagefile.file.extension.downcase.to_sym

        # If the original file is SVG, serve up the converted version.
        if original_format == :svg
          # Generate the PNG if it doesn't already exist
          @picto.images.last.imagefile.recreate_versions! unless @picto.images.last.imagefile.svg2png.file.exists?
          path = @picto.images.last.imagefile.svg2png.path
        elsif original_format == :png
          # If the original is a PNG, serve it up.
          path = @picto.images.last.imagefile.path
        else
          # Otherwise, we cannot fulfil this request
          raise ActiveRecord::RecordNotFound
        end

        # Check if file exists before sending to prevent 502 errors
        if File.exist?(path)
        send_file path, filename: "#{@picto.best_label_for(locale).text}_#{@picto.id}.png", disposition: disposition
        else
          raise ActiveRecord::RecordNotFound
        end
      end

      format.svg do
        imagefile = @picto.images.last.imagefile
        raise ActiveRecord::RecordNotFound unless imagefile.file.extension.downcase == 'svg'
        # Check if file exists before sending to prevent 502 errors
        if File.exist?(imagefile.path)
        send_file imagefile.path, filename: "#{@picto.best_label_for(locale).text}_#{@picto.id}.svg", disposition: disposition
        else
          raise ActiveRecord::RecordNotFound
        end
      end

      format.jpeg do
        imagefile = @picto.images.last.imagefile
        raise ActiveRecord::RecordNotFound unless imagefile.file.extension.downcase == 'jpg'
        # Check if file exists before sending to prevent 502 errors
        if File.exist?(imagefile.path)
        send_file imagefile.path, filename: "#{@picto.best_label_for(locale).text}_#{@picto.id}.jpg", disposition: disposition
        else
          raise ActiveRecord::RecordNotFound
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
end
