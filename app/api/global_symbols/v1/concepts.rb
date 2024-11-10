module GlobalSymbols
  class V1::Concepts < Grape::API
    
    resource :concepts do
      
      desc 'Returns Concepts matching a query',
        detail: 'Returns Concepts matching the supplied query, including the Pictos matched against each Concept. Various filters are available.',
        success: V1::Entities::Concept,
        is_array: true
      
      params do
        requires :query, type: String, desc: 'Concept name to search for.'
        optional :symbolset, type: String, desc: 'Slug of a Symbolset to search within, as it appears in URLs on globalsymbols.com. Leave blank to search all Symbolsets.', values: -> { Symbolset.published.pluck(:slug) }
        optional :language, type: String, desc: 'ISO639 language code. Two-letter codes are ISO639-1. Use the Languages endpoint to find values.', default: 'eng', values: -> { Language.where(active: true).pluck(:iso639_3, :iso639_2b, :iso639_2t, :iso639_1).flatten.uniq }
        optional :language_iso_format, type: String, desc: 'ISO639 format to use for the language parameter.', default: '639-3', values: ['639-1', '639-2b', '639-2t', '639-3']
        optional  :limit, type: Integer, desc: 'Limit the number of search results.', default: 10, values: (1..100).to_a
      end
      get :suggest do
        params[:query].downcase!
        
        # Replace spaces with underscores in the query. Cannot use parameterize() because it wipes out Arabic text.
        query = params[:query].tr_s(' ', '_')
        
        language_code_column = params[:language_iso_format].underscore
        language = Language.find_by!("iso#{language_code_column}": params[:language])
        
        symbolset = Symbolset.find_by(slug: params[:symbolset])
        
        # Using Arel to build the case/when for prioritisation of results.
        # This prioritises by whole word first, then beginning of word, then in-word.
        # For instance, searching 'cat' should show, in order, 'cat', 'category', 'fat_cat'
        concept_subject_field = Concept.arel_table[:subject]
        
        order_case = Arel::Nodes::Case.new
         .when(concept_subject_field.eq(query))              .then(0)  # "cat"
         .when(concept_subject_field.matches("#{query}\\_%"))  .then(10) # "cat_bed"
         .when(concept_subject_field.matches("%\\_#{query}"))  .then(20) # "black_cat"
         .when(concept_subject_field.matches("%\\_#{query}\\_%")).then(30) # "black_cat_sleeping"
         .when(concept_subject_field.matches("#{query}%"))   .then(40) # "cathartic"
         .when(concept_subject_field.matches("%#{query}"))   .then(50) # "fatcat"
         .else(60) # no match
        
        concepts = Concept
                       .where("subject LIKE ?", "%#{query}%")
                       .where(language: language)
                       .order(order_case)
                       .order(:subject)
                       .limit(params[:limit])
        
        # If a target Symbolset was specified, limit the search to that set.
        # This prevents Concepts being found from other Symbolsets, but the Presenter (below) still has to be told
        # to present only the correct Pictos.
        if symbolset.present?
          concepts = concepts
                         .joins(:pictos)
                         .where(pictos: {symbolset: symbolset})
        end
        
        # The expose_pictos_from_symbolset option ensures the presenter will show only Pictos from the specified Symbolset.
        present concepts, with: V1::Entities::Concept, expose_pictos_from_symbolset: symbolset
      end
      
      desc 'Returns a Concept',
        detail: 'Finds and returns a single Concept, with associated Pictos.',
        success: V1::Entities::Concept,
        failure: [[404, 'Not Found', V1::Entities::Error]]
      
      params do
        requires :id, type: Integer, desc: 'Concept ID.'
      end
      route_param :id do
        get do
          present Concept.find(params[:id]), with: V1::Entities::Concept#, type: :full
        end
      end
    end
  end
end