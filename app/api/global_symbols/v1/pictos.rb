module GlobalSymbols
  class V1::Pictos < Grape::API
    
    resource :pictos do
      
      desc 'Returns Pictos (symbols) for a Symbolset',
        detail: 'Returns paginated list of Pictos for the specified Symbolset, including all authoritative labels with their languages.',
        success: V1::Entities::PagedPictosResponse,
        is_array: false
      
      params do
        requires :symbolset, type: String, desc: 'Slug of a Symbolset to list Pictos for, as it appears in URLs on globalsymbols.com.', values: -> { Symbolset.published.pluck(:slug) }
        optional :page, type: Integer, desc: 'Page number for pagination.', default: 1
        optional :per_page, type: Integer, desc: 'Number of items per page.', default: 100
      end
      
      get do
        symbolset = Symbolset.published.find_by!(slug: params[:symbolset])
        
        # Build the base scope for pictos in this symbolset
        scope = Picto.where(symbolset: symbolset)
                     .where(archived: false, visibility: :everybody)
        
        # Eager load associations to avoid N+1 queries
        scope = scope.includes(:images, labels: [:language, :source])
        
        # Calculate total before pagination
        total = scope.count
        
        # Apply pagination
        page = [params[:page].to_i, 1].max
        per_page = [[params[:per_page].to_i, 1].max, 100].min
        
        paged = scope.order(:id)
                     .offset((page - 1) * per_page)
                     .limit(per_page)
        
        # Return paginated response
        present({
          items: paged,
          total: total
        }, with: V1::Entities::PagedPictosResponse)
      end
    end
  end
end
