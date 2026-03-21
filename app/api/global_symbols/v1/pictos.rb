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
        optional :since, type: String, desc: 'ISO 8601 timestamp to filter for pictos created or updated after this time (delta fetching). Response includes pictos created or updated after this time, plus a deletions array of IDs that were archived since that timestamp.'
      end
      
      get do
        symbolset = Symbolset.published.find_by!(slug: params[:symbolset])

        # Build the base scope for pictos in this symbolset (including archived so we can track deletions)
        base_scope = Picto.where(symbolset: symbolset)

        # Common pagination values
        page = [params[:page].to_i, 1].max
        per_page = [[params[:per_page].to_i, 1].max, 100].min

        if params[:since].present?
          begin
            since_time = Time.iso8601(params[:since])
          rescue ArgumentError
            error!(
              {
                error: "Invalid 'since' timestamp. Use ISO 8601 format (e.g., 2026-01-01T00:00:00Z).",
                code: 400,
                with: V1::Entities::Error
              },
              400
            )
          end

          # All pictos in this symbolset that changed since the timestamp (additions, updates, and archival)
          changed_scope = base_scope.where('updated_at > ?', since_time)

          # Visible, non-archived pictos for the response items
          items_scope = changed_scope.where(archived: false, visibility: :everybody)
                                     .includes(:images, labels: [:language, :source])

          # Total number of changes before pagination (additions + updates + deletions)
          total = changed_scope.count

          # IDs of pictos archived since the timestamp (always included in delta response)
          deletions = changed_scope.where(archived: true).pluck(:id)

          # Latest modification timestamp among pictos that changed since the supplied `since` value
          last_updated = changed_scope.maximum(:updated_at)&.iso8601

          paged_items = items_scope.order(:id)
                                   .offset((page - 1) * per_page)
                                   .limit(per_page)

          response = {
            items: paged_items,
            total: total,
            deletions: deletions
          }
          response[:last_updated] = last_updated if last_updated

          present(response, with: V1::Entities::PagedPictosResponse)
        else
          # Original behaviour: full fetch for symbolset, only non-archived and public pictos
          scope = base_scope.where(archived: false, visibility: :everybody)
                            .includes(:images, labels: [:language, :source])

          # Calculate total before pagination
          total = scope.count

          # Apply pagination
          paged = scope.order(:id)
                       .offset((page - 1) * per_page)
                       .limit(per_page)

          present({
            items: paged,
            total: total
          }, with: V1::Entities::PagedPictosResponse)
        end
      end
    end
  end
end
