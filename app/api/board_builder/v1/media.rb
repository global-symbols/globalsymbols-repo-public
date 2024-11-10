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
      end
      oauth2 'boardset:read'
      get do
        media = Boardbuilder::Media.accessible_by(current_ability).where(user: current_user)
        media = media.includes(cells: { board: :board_set } ) if params[:expand]

        present media.order(updated_at: :desc), with: Entities::Media, expand: params[:expand]
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
