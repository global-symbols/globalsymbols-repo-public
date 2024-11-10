class TranslationController < ApplicationController

  load_and_authorize_resource :label, class: Label, except: [:suggest_all]

  def show
  end

  def create
    @picto = Picto.find(label_params[:picto_id])
    authorize! :manage, @picto

    @label = Label.create!(
      language_id: label_params[:language_id],
      picto: @picto,
      source: Source.find_by!(slug: 'translation'),
      text: label_params[:text]
    )

    respond_to do |format|
      format.html {
        redirect_to translate_symbolset_path @label.picto.symbolset
      }
      format.js { render 'create' } # Replaces the partial
    end


  end

  def update
    @picto = Picto.find(params[:id])
    @label = @picto.labels.find(label_params[:label_id])
    authorize! :manage, @label

    if @label.update!(
      source: Source.find_by!(slug: 'translation'),
      text: label_params[:text]
    )
      respond_to do |format|
        format.html {
          redirect_to translate_symbolset_path @label.picto.symbolset
        }
        format.js { render 'update' } # Replaces the partial
      end
    else
      render 'edit'
    end
  end

  def suggest
    @picto = Picto.find(suggestion_params[:picto_id])
    authorize! :manage, @picto

    @source_language = Language.find(suggestion_params[:source_language_id])
    @destination_language = Language.find(suggestion_params[:destination_language_id])

    @source_label = @picto.labels.find_by!(language: @source_language)

    translator = BingTranslator.new(AZURE_TRANSLATOR_KEY)

    begin
      translation = translator.translate(@source_label.text, from: @source_language.azure_code, to: @destination_language.azure_code)

      if translation

        # If the Picto has an existing translation suggestion for this Language, replace the suggestion
        # instead of creating a new one.
        @label =  Label.find_or_initialize_by({
          language: @destination_language,
          picto_id: @picto.id,
          source: Source.find_by!(slug: 'translation-suggestion'),
        })
        @label.text = translation
        @label.save!

        respond_to do |format|
          format.js { render 'suggest' } # Replaces the partial
        end
      end

    rescue BingTranslator::Exception => e
      Sentry.capture_exception(e)
      Sentry.capture_message("translation suggest failed for source lang #{@source_language.name} (#{@source_language.iso639_3}, #{@source_language.iso639_1}) to dest lang #{@destination_language.name} (#{@destination_language.iso639_3}, #{@destination_language.iso639_1})")
    end

  end

  def suggest_all

    @limit = 35
    @symbolset = Symbolset.find(params[:translation_id])
    authorize! :manage, @symbolset

    @source_language = Language.find(suggestion_params[:source_language_id])
    @destination_language = Language.find(suggestion_params[:destination_language_id])

    @source_labels        = Label.unscoped.joins(:picto).where(pictos: { symbolset_id: @symbolset.id}, language: @source_language)
    @existing_dest_labels = Label.unscoped.joins(:picto).where(pictos: { symbolset_id: @symbolset.id}, language: @destination_language)

    # Find source labels of pictos that do not have a label in the destination language.
    @labels_to_translate = @source_labels.where.not(picto_id: @existing_dest_labels.select(:picto_id).pluck(:picto_id)).limit(@limit)

    suggestion_source = Source.find_by!(slug: 'translation-suggestion')

    translator = BingTranslator.new(AZURE_TRANSLATOR_KEY)

    begin
      translations = translator.translate_array(@labels_to_translate.pluck(:text), from: @source_language.azure_code, to: @destination_language.azure_code)

      translations.each_with_index do |translation, index|

        # If the Picto has an existing translation suggestion for this Language, replace the suggestion
        # instead of creating a new one.
        label =  Label.find_or_initialize_by({
          language: @destination_language,
          picto_id: @labels_to_translate[index].picto_id,
          source: suggestion_source,
        })
        label.text = translation
        label.save
      end

      @translated_labels = Label.unscoped.joins(:source, picto: :symbolset).where(pictos: { symbolset: @symbolset }, language: @destination_language, sources: {authoritative: true})

      @pictos = @symbolset.pictos.where(archived: false).accessible_by(current_ability).includes(:images, :labels, :source)
      @pictos = @pictos.where.not(id: @translated_labels.pluck(:picto_id)).limit(@limit)


      respond_to do |format|
        format.js { render 'suggest_all' } # Replaces the partial
      end

    rescue BingTranslator::Exception => e
      Sentry.capture_exception(e)
      Sentry.capture_message("translation suggest_all failed for source lang #{@source_language.name} (#{@source_language.iso639_3}, #{@source_language.iso639_1}) to dest lang #{@dest_language.name} (#{@dest_language.iso639_3}, #{@dest_language.iso639_1})")
    end

  end

  def accept_all
    @symbolset = Symbolset.find(params[:translation_id])
    authorize! :manage, @symbolset

    @source_language = Language.find(suggestion_params[:source_language_id])
    @dest_language = Language.find(suggestion_params[:destination_language_id])

    @suggested_labels = Label.unscoped.joins(:picto, :source).where(pictos: { symbolset_id: @symbolset.id}, language: @dest_language, source: { slug: 'translation-suggestion'})

    @suggested_labels.update_all(source_id: Source.find_by!(slug: 'translation').id)

    respond_to do |format|
      format.js { render 'accept_all' } # Replaces the partial
    end
  end

  private

  def suggestion_params
    params.require(:label).permit(:picto_id, :source_language_id, :destination_language_id)
  end

  def label_params
    params.require(:label).permit(:text, :picto_id, :label_id, :language_id)
  end
end
