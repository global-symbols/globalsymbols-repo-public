module GlobalSymbols
  class V1::Symbolsets < Grape::API
  
    resource :symbolsets do
      desc 'Returns all published Symbol Sets',
        success: V1::Entities::Symbolset,
        is_array: true
      
      get do
        present Symbolset.published.order('ISNULL(featured_level)').order(:name), with: V1::Entities::Symbolset
      end
    end
  end
end