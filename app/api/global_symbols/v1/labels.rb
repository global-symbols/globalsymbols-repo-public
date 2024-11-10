module GlobalSymbols
  class V1::Labels < Grape::API

    include V1::Defaults
    
    resource :labels do
      
      desc 'Returns Labels matching the query.',
        detail: 'Returns Labels matching the supplied query, including the Picto associated with the Label. Various filters are available.',
        success: V1::Entities::Label,
        is_array: true
      
      params do
        requires :query, type: String, desc: 'Label name to search for.'
        optional :symbolset, type: String, desc: 'Slug of a Symbolset to search within, as it appears in URLs on globalsymbols.com. Leave blank to search all Symbolsets.', values: -> { Symbolset.published.pluck(:slug) }
        optional :language, type: String, desc: 'ISO639 language code. Two-letter codes are ISO639-1. Use the Languages endpoint to find values.', default: 'eng', values: -> { Language.where(active: true).pluck(:iso639_3, :iso639_2b, :iso639_2t, :iso639_1).flatten.uniq.reject {|l| l.nil?}.sort }
        optional :language_iso_format, type: String, desc: 'ISO639 format to use for the language parameter.', default: '639-3', values: ['639-1', '639-2b', '639-2t', '639-3']
        optional  :limit, type: Integer, desc: 'Limit the number of search results.', default: 10, values: (1..100).to_a
        use :expand
      end
      get :search do
        query = params[:query].strip
        
        language_code_column = params[:language_iso_format].underscore
        
        # Using Arel to build the case/when for prioritisation of results.
        # This prioritises by whole word first, then beginning of word, then in-word.
        # For instance, searching 'cat' should show, in order, 'cat', 'category', 'fat_cat'
        label_text_field = Label.arel_table[:text]
        
        order_case = Arel::Nodes::Case.new
         .when(label_text_field.eq(query))              .then(0)  # "cat"
         .when(label_text_field.matches("#{query}\\_%"))  .then(10) # "cat_bed"
         .when(label_text_field.matches("%\\_#{query}"))  .then(20) # "black_cat"
         .when(label_text_field.matches("%\\_#{query}\\_%")).then(30) # "black_cat_sleeping"
         .when(label_text_field.matches("#{query}%"))   .then(40) # "cathartic"
         .when(label_text_field.matches("%#{query}"))   .then(50) # "fatcat"
         .else(60) # no match
        
        labels = Label.authoritative.where("text LIKE ?", "%#{query}%")
                      .joins(:language)
                      .where(languages: { "iso#{language_code_column}": params[:language] })
                      .joins(picto: :symbolset)
                      .where(
                        pictos: {
                          archived: false,
                          symbolsets: {status: :published}
                        }
                      )
                      .order(order_case)
                      .order(:text)
                      .limit(params[:limit])
        
        # If a target Symbolset was specified, limit the search to that set.
        # This prevents Labels being found from other Symbolsets, but the Presenter (below) still has to be told
        # to present only the correct Pictos.
        if params[:symbolset]
          labels = labels.where(pictos: {symbolsets: { slug: params[:symbolset] }})
        end

        labels = labels.includes(:language, picto: {symbolset: :licence}).includes(picto: :images)

        present labels, with: V1::Entities::Label, expand: params[:expand]
      end
      
      desc 'Returns a Label.',
        detail: 'Finds and returns a single Label, with the associated Picto.',
        success: V1::Entities::Label,
        failure: [[404, 'Not Found', V1::Entities::Error]]
      
      params do
        requires :id, type: Integer, desc: 'Label ID.'
        use :expand
      end
      route_param :id do
        get do
          present Label.authoritative.accessible_by(current_ability).find(params[:id]), with: V1::Entities::Label, expandcan: params[:expand]
        end
      end
    end
  end
end