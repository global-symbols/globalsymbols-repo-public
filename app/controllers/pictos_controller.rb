class PictosController < ApplicationController
  
  skip_before_action :authenticate_user!, only: [:index, :show]
  load_and_authorize_resource :symbolset, find_by: :slug
  load_and_authorize_resource :picto, through: :symbolset

  add_breadcrumb 'Symbolsets', :symbolsets, only: [:index, :show]
  
  def show
    respond_to do |format|
  
      # Set whether the file should be downloaded or shown in the browser
      disposition = (params['download'] && params['download'] == '1') ? :attachment : :inline
      
      format.html {

        # @picto = @picto.eager_load(:symbolset, :labels)

        add_breadcrumb(@picto.symbolset.name, symbolset_url(@picto.symbolset))
        add_breadcrumb(@picto.labels.first.text, symbolset_symbol_url(@picto.symbolset, @picto))
  
        @alternative_pictos = @picto.alternative_pictos.accessible_by(current_ability).page params[:page]
        @comment = Comment.new
        @surveys = Survey.accessible_by(current_ability, :manage)
      }

      format.png {
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

        send_file path, filename: "#{@picto.best_label_for(locale).text}_#{@picto.id}.png", disposition: disposition
      }

      # Serve SVG
      format.svg {
        imagefile = @picto.images.last.imagefile
        raise ActiveRecord::RecordNotFound unless imagefile.file.extension.downcase == 'svg'
        send_file imagefile.path, filename: "#{@picto.best_label_for(locale).text}_#{@picto.id}.svg", disposition: disposition
      }

      # Serve JPG
      format.jpeg {
        imagefile = @picto.images.last.imagefile
        raise ActiveRecord::RecordNotFound unless imagefile.file.extension.downcase == 'jpg'
        send_file imagefile.path, filename: "#{@picto.best_label_for(locale).text}_#{@picto.id}.jpg", disposition: disposition
      }
      
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
    if @picto.save
      redirect_to symbolset_symbol_path(id: @picto)
    else
      @picto.images.build if @picto.images.empty?
    end
  end
  
  def update
    redirect_to symbolset_symbol_path if @picto.update(picto_params)
  end

  def destroy
    @picto.destroy
    redirect_to symbolset_path @symbolset
  end
  
  def comment
    @picto = Picto.find(params[:id])
    @comment = Comment.new(comment_params)
    @comment.user = current_user
    @comment.picto = @picto
    if @comment.save
      redirect_to(symbolset_symbol_path(@picto.symbolset, @picto))
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
