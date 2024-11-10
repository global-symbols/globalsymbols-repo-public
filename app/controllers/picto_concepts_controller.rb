class PictoConceptsController < ApplicationController
  
  load_and_authorize_resource :symbolset, find_by: :slug
  load_and_authorize_resource :symbol, class: Picto
  load_and_authorize_resource :picto_concept, through: :symbol, except: [:create]
  
  def index
  end

  def create
    if picto_concept_params[:concept].present?
      # Finds the Language by the provided iso316_3 code, or default to 'eng'
      language = Language.find_by(iso639_3: (picto_concept_params[:iso639_3_code] || 'eng'))
      begin
        if @symbol.add_concept(picto_concept_params[:concept], language)
          flash[:notice] = I18n.t('views.picto_concepts.create.notice_success', concept: picto_concept_params[:concept])
        else
          flash[:alert] = I18n.t('views.picto_concepts.create.alert_failure', concept: picto_concept_params[:concept])
        end
      rescue ActiveRecord::RecordInvalid
        flash[:alert] = I18n.t('views.picto_concepts.create.alert_already_exists', concept: picto_concept_params[:concept])
      end
    end

    respond_to do |format|
      format.html {
        redirect_to symbolset_symbol_concepts_path
      }
      format.js { render 'destroy' } # Replaces the partial
    end
  end

  def destroy
    concept = @picto_concept.concept
    
    success = @picto_concept.destroy
    respond_to do |format|
      format.html {
        if success
          flash[:notice] = I18n.t('views.picto_concepts.destroy.notice_success', concept: concept.subject)
        else
          flash[:alert] = I18n.t('views.picto_concepts.destroy.alert_failure', concept: concept.subject)
        end
        redirect_to symbolset_symbol_concepts_path
      }
      format.js {}
    end
  end

  private
  
    def picto_concept_params
      params.permit(:concept, :iso639_3_code)
    end
end
