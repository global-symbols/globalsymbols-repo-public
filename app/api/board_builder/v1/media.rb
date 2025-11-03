module BoardBuilder::V1
  class FileIO < StringIO
    def initialize(stream, filename)
      super(stream)
      @original_filename = filename
    end

    attr_reader :original_filename
  end

  class Media < Grape::API

    helpers SharedHelpers

    resource :media do

      # POST Creation

      desc 'Creates a Media item belonging to the current user',
        success: Entities::Media
      params do
        requires :file, type: File, desc: 'Image file. SVG, JPG or PNG.'
        optional :canvas, type: File, desc: 'FabricJS serialised canvas as a JSON file.'
        optional :caption, type: String, desc: 'Image caption'
      end
      oauth2 'boardset:write'
      post do
        media = Boardbuilder::Media.new(
            user: current_user,
            file: params[:file][:tempfile]
        )

        media.canvas = params[:canvas] if params[:canvas]

        # pp params[:canvas].to_json

        # if params[:canvas]
        #   # Prepare a StringIO of the Canvas JSON.
        #   # This will be used by the Carrierwave uploader.
        #   canvas_stringio = StringIO.new(params[:canvas].to_json)
        #   # We have to fool Carrierwave by providing a filename in the StringIO.
        #   def canvas_stringio.original_filename; 'temp.json'; end
        # end

        # if params[:canvas]
        #   puts 'its a canvas'
        #   pp params[:canvas].to_json
        #   media.canvas = FileIO.new(params[:canvas].to_json, 'temp.json') if params[:canvas]
        # end

        media.save!
        present media, with: Entities::Media
      end



      desc 'Returns Media belonging to the current user',
        success: Entities::Media,
        is_array: true
      params do
        use :expand
        optional :page, type: Integer, default: 1
        optional :per_page, type: Integer, default: 100
      end
      oauth2 'boardset:read'
      get do
        scope = Boardbuilder::Media
                  .accessible_by(current_ability)
                  .where(user: current_user)
                  .where.not(id: Boardbuilder::BoardSet.select(:thumbnail_id).where.not(thumbnail_id: nil))
        scope = scope.includes(cells: { board: :board_set } ) if params[:expand]

        # Always use pagination for media library requests
        page = [params[:page].to_i, 1].max
        per_page = [[params[:per_page].to_i, 1].max, 100].min

        total = scope.count

        paged = scope
                  .order(updated_at: :desc)
                  .offset((page - 1) * per_page)
                  .limit(per_page)

        # Return paginated response
        present({
          items: paged,
          total: total
        }, with: Entities::PagedMediaResponse)
      end

      desc 'Destroys unreferenced Media belonging to the current user'
      oauth2 'boardset:write'
      delete "delete_unreferenced" do
        referenced_in_cells = Boardbuilder::Cell.accessible_by(current_ability).where.not(boardbuilder_media_id: nil).pluck(:boardbuilder_media_id)
        referenced_as_thumbnail = Boardbuilder::BoardSet.accessible_by(current_ability).where.not(thumbnail_id: nil).pluck(:thumbnail_id)
        referenced_as_header = Boardbuilder::Board.accessible_by(current_ability).where.not(header_boardbuilder_media_id: nil).pluck(:header_boardbuilder_media_id)
        referenced_ids = referenced_in_cells + referenced_as_thumbnail + referenced_as_header

        unreferenced_media = Boardbuilder::Media.where(user_id: current_user.id).where.not(id: referenced_ids)
        count = unreferenced_media.count
        unreferenced_media.delete_all
        present ({ "deleted" => count })
      end

      route_param :id do

        desc 'Returns a specific Media accessible to the current user',
          success: Entities::Media
        params do
          use :expand
        end
        oauth2 'boardset:read'
        get do
          mediaItem = Boardbuilder::Media.accessible_by(current_ability)
          mediaItem = mediaItem.includes(cells: { board: :board_set } ) if params[:expand]
          mediaItem = mediaItem.find(params[:id])

          present mediaItem, with: Entities::Media, expand: params[:expand]
        end


        desc 'Updates a Media belonging to the current user',
          success: Entities::Media
        params do
          optional :file, type: File, desc: 'Image file. SVG, JPG or PNG.'
          optional :canvas, type: File, desc: 'FabricJS serialised canvas as a JSON file.'
          optional :caption, type: String, desc: 'Image caption'
        end
        oauth2 'boardset:write'
        patch do
          media = Boardbuilder::Media.accessible_by(current_ability).find_by(user: current_user, id: params[:id])
          authorize! :manage, media
          media.update!(declared(params, include_missing: false))
          present media, with: Entities::Media
        end

        desc 'Destroys a Media belonging to the current user'
        oauth2 'boardset:write'
        delete do
          media = Boardbuilder::Media.accessible_by(current_ability).find_by(user: current_user, id: params[:id])
          authorize! :manage, media
          media.destroy!
          present nil
        end
      end
    end
  end
end
