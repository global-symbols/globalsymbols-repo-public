class PictoLabelsController < ApplicationController
  
  load_and_authorize_resource :symbolset, find_by: :slug
  load_and_authorize_resource :symbol, class: Picto
  load_and_authorize_resource :label, through: :symbol, parent: false, class: Label
  
  def index
    @label = Label.new
  end
  
  def create
    @label.picto_id = @symbol.id
    @label.source = Source.find_by!(slug: 'translation')
    
    if @label.save
      flash[:notice] = I18n.t('views.picto_labels.create.notice_success', label: label_params[:text])
      redirect_to symbolset_symbol_labels_path
    else
      flash[:alert] = I18n.t('views.picto_labels.create.alert_failure')
    end
  end
  
  def edit
  end
  
  def update
    @label.source = Source.find_by!(slug: 'global-symbols') unless @label.source.slug.starts_with? 'translation'
    if @label.update(label_params)
      redirect_to symbolset_symbol_labels_path
    else
      render 'edit'
    end
  end
  
  def destroy
    success = @label.destroy
    respond_to do |format|
      format.html {
        if success
          flash[:notice] = I18n.t('views.picto_labels.destroy.notice_success', label: @label.text)
        else
          flash[:alert] = I18n.t('views.picto_labels.destroy.alert_failure', label: @label.text)
        end
        redirect_to symbolset_symbol_labels_path
      }
      format.js {}
    end
  
  end

  def publish_translation
    @label.update!(
      source: Source.find_by(slug: 'translation')
    )

    flash[:notice] = I18n.t('views.picto_labels.publish_translation.notice_success', language_name: @label.language.name)

    redirect_to symbolset_symbol_labels_path
  end
  
  private
    
    def label_params
      params.require(:label).permit(:text, :text_diacritised, :description, :language_id)
    end
end
