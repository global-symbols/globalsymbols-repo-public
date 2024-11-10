module GlobalSymbols
  class V1::Languages < Grape::API
    
    resource :languages do
      desc 'Returns all active Languages',
        detail: 'Returns Languages that are marked as active.',
        success: V1::Entities::Language,
        is_array: true
      
      get :active do
        present Language.where(active: true), with: V1::Entities::Language
      end
    end
  end
end