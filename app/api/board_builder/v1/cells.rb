module BoardBuilder::V1
  class Cells < Grape::API

    helpers SharedHelpers

    resource :cells do


      desc 'Returns Cells belonging to the current user',
           success: Entities::Cell,
           is_array: true
      params do
        requires :board_id, type: Integer, desc: 'Board ID'
        use :expand
      end
      oauth2 'boardset:read'
      get do
        present Boardbuilder::Board.accessible_by(current_ability).find(params[:board_id]).cells, with: Entities::Cell, expand: params[:expand]
      end



      route_param :id do

        desc 'Returns a specific Cell belonging to the current user',
             success: Entities::Cell
        params do
          use :expand
        end
        oauth2 'boardset:read'
        get do
          present Boardbuilder::Cell.accessible_by(current_ability).find(params[:id]), with: Entities::Cell, expand: params[:expand]
        end


        desc 'Updates a Cell belonging to the current user',
          success: Entities::Cell
        params do
          optional :caption, type: String, desc: 'Text in the Cell'
          optional :background_colour, type: String, desc: 'Background colour in hex format'
          optional :border_colour, type: String, desc: 'Background colour in hex format'
          optional :text_colour, type: String, desc: 'Background colour in hex format'
          optional :hair_colour, type: String, desc: 'Hair colour in hex format. For adaptable symbols only'
          optional :skin_colour, type: String, desc: 'Skin colour in hex format. For adaptable symbols only'
          optional :image_url, type: String, desc: 'URL of the image to appear in the cell. Must be HTTPS.'
          optional :linked_board_id, type: Integer, desc: 'ID of the Board this Cell is linked to.', as: :linked_to_boardbuilder_board_id
          optional :picto_id, type: Integer, desc: 'ID of a Global Symbols Picto used in the Cell.'
          optional :media_id, type: Integer, desc: 'ID of a User Media item used in the Cell.', as: :boardbuilder_media_id
        end
        oauth2 'boardset:write'
        patch do
          cell = Boardbuilder::Cell.accessible_by(current_ability).find(params[:id])
          cell.update!(declared(params, include_missing: false))
          present cell, with: Entities::Cell
        end




        desc 'Uploads an image file into a Cell',
          success: Entities::Cell
        params do
          requires :image, type: File, desc: 'Image file. SVG, JPG or PNG.'
        end
        oauth2 'boardset:write'
        patch do
          cell = Boardbuilder::Cell.accessible_by(current_ability).find(params[:id])

          # Remove any existing library_image from the Cell, and delete the image if no Cells are linked to it.
          if cell.library_image.present?
            li = cell.library_image
            cell.update(library_image: nil, url: nil)
            li.destroy if li.reload.cells.empty?
          end

          cell.update!(declared(params, include_missing: false))
          present cell, with: Entities::Cell
        end
      end
    end
  end
end
