module BoardBuilder
  class V1::Search < Grape::API
    
    resource :symbols do
      desc 'Searches Symbols',
           success: V1::Entities::SearchResult,
           is_array: true
      
      params do
        requires :query, type: String, desc: 'Text to search for.'
        optional :source, type: String, desc: 'Source to search.', default: 'globalsymbols', values: ['globalsymbols', 'the-noun-project']
      end
      
      get :search do
        results = []
        if params[:source] === 'the-noun-project'
          consumer = OAuth::Consumer.new(NOUN_PROJECT_API_KEY, NOUN_PROJECT_API_SECRET, site: "https://api.thenounproject.com")
          response = consumer.request(:get, "https://api.thenounproject.com/icons/#{URI.encode(params[:query])}", nil, {}, {})

          # TNP returns 404 when no symbols are found, instead of an empty set.
          # Only populate results if the response is 200
          if response.code == '200'
            icons = JSON.parse(response.body)['icons']

            icons.each do |icon|
              # pp icon
              results << {
                  id: icon['id'],
                  label: icon['term'],
                  tooltip: "#{icon['term']} in The Noun Project",
                  imageUrl: icon['preview_url']
              }
            end
          end
        end
        
        present results, with: V1::Entities::SearchResult
      end
    end
  end
end