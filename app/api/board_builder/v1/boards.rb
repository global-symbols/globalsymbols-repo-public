module BoardBuilder::V1
  class Boards < Grape::API

    helpers SharedHelpers

    resource :boards do


      desc 'Creates a Board belonging to the current user',
           success: Entities::Board
      params do
        requires :board_set_id, type: Integer, desc: 'Board Set ID', as: :boardbuilder_board_set_id
        requires :name, type: String, desc: 'Board name'
        optional :description, type: String, desc: 'Board description'
        optional :columns, type: Integer, desc: 'Number of columns', default: 4
        optional :rows, type: Integer, desc: 'Number of rows', default: 3
        optional :captions_position, type: String, desc: 'Default caption position within Cells', default: 'below'

        optional :cells, as: :cells_attributes, type: Array[JSON] do
          optional :caption, type: String, desc: 'Text in the Cell'
          optional :background_colour, type: String, desc: 'Background colour in hex, rgb() or rgba() format'
          optional :border_colour, type: String, desc: 'Background colour in hex, rgb() or rgba() format'
          optional :text_colour, type: String, desc: 'Background colour in hex, rgb() or rgba() format'
          optional :image_url, type: String, desc: 'URL of the image to appear in the cell. Must be HTTPS.'
          optional :linked_board_id, type: Integer, desc: 'ID of the Board this Cell is linked to.', as: :linked_to_boardbuilder_board_id
        end
      end
      oauth2 'boardset:write'
      post do
        present Boardbuilder::Board.create!(declared(params, include_missing: false)), with: Entities::Board
      end


      desc 'Returns Boards belonging to the current user',
           success: Entities::Board,
           is_array: true
      params do
        requires :board_set_id, type: Integer, desc: 'BoardSet ID'
        use :expand
      end
      oauth2 'boardset:read'
      get do
        present Boardbuilder::Board.accessible_by(current_ability), with: Entities::Board, expand: params[:expand]
      end


      desc 'Uploads an OBF file, adding a Board to the specified BoardSet'
      oauth2 'boardset:write'
      params do
        requires :obf, type: JSON, desc: 'OBF File'
        requires :board_set_id, type: Integer, desc: 'Board Set ID to add the OBF Board to.'
      end
      post :obf do

        createdMedia = []

        begin
          obf = params[:obf]
          board_set = Boardbuilder::BoardSet.accessible_by(current_ability).find(params[:board_set_id])
          authorize! :manage, board_set
          board = board_set.boards.new

          board.name    = obf['name']
          board.rows    = obf['grid']['rows']
          board.columns = obf['grid']['columns']

          # OBF grid.order is a matrix, so we flatten it to get the cells in sequential order.
          obf['grid']['order'].flatten.each do |obfCellId|

            cell = board.cells.new

            # If the cell ID is not null (CBoard OBFs have null cell IDs on unused cells).
            if obfCellId

              # Find the associated button (i.e. cell) and image
              obfButton = obf['buttons'].find{ |button| button['id'] === obfCellId }
              obfImage  = obf['images'].find{ |image| image['id'] === obfButton['image_id'] }

              # If a button is present, add the label, colours, etc
              if obfButton
                cell.caption = obfButton['label']
                cell.border_colour = obfButton['border_color']
                cell.background_colour = obfButton['background_color']
              end

              # If an image is present, link to the URL or load the embedded base64 image
              if obfImage
                if obfImage['url']
                  cell.image_url = obfImage['url']
                elsif obfImage['data']
                  media = Boardbuilder::Media.new(user: current_user)

                  media.file = obfImage['data']
                  media.save!
                  createdMedia << media

                  cell.image_url = media.file.url
                  cell.media = media
                end
              end

            end
          end

          board.save!
          present board, with: Entities::Board

        rescue Exception => e
          # If an error occurs, remove any uploaded Media.
          createdMedia.each do |media|
            media.destroy
          end
          raise e
        end
      end


      route_param :id do

        desc 'Returns a specific Board belonging to the current user',
             success: Entities::Board,
             is_array: false
        params do
          requires :id, type: Integer, desc: 'Board ID'
          use :expand
        end
        oauth2 'boardset:read'
        get do
          present Boardbuilder::Board.accessible_by(current_ability).find(params[:id]), with: Entities::Board, expand: params[:expand]
        end


        desc 'Updates a Board belonging to the current user',
             success: Entities::Board,
             is_array: false
        params do
          optional :name, type: String, desc: 'Board name'
          optional :description, type: String, desc: 'Board description'
          optional :captions_position, type: String
          optional :columns, type: Integer
          optional :rows, type: Integer
          optional :header_media_id, as: :header_boardbuilder_media_id, type: Integer, desc: 'Header Media item ID'
        end
        oauth2 'boardset:write'
        patch do
          board = Boardbuilder::Board.accessible_by(current_ability).find(params[:id])
          pp declared(params)
          board.update!(declared(params, include_missing: false))
          present board, with: Entities::Board
        end


        desc 'Destroys a Board belonging to the current user'
        oauth2 'boardset:write'
        delete do
          board = Boardbuilder::Board.accessible_by(current_ability).find(params[:id])
          board.destroy!
          present nil
        end
        
        
        desc 'Returns a PDF of a Board'
        oauth2 'boardset:write'
        params do
          requires :id, type: Integer, desc: 'Board ID'
          optional :download, type: Boolean, desc: 'When true, sets Content-Disposition to attachment, so the file downloads. When false, sets Content-Disposition to inline.', coerce: Boolean
          optional :orientation, type: String, values: ['portrait', 'landscape']
          optional :fontSize, type: Integer
          optional :pageSize, type: Hash do
            requires :name, type: String, values: PDF::Core::PageGeometry::SIZES.keys, default: 'A4'
          end
          optional :cellSpacing, type: Integer, desc: 'Spacing between cells. Recommended values 0-50'
          optional :cellPadding, type: Integer, desc: 'Spacing inside cells. Recommended values 0-50'
          optional :drawCellBorders, type: Boolean, desc: 'Enables or disables drawing of cell boundaries.', coerce: Boolean
          optional :imageTextSpacing, type: Integer, desc: 'Spacing between image and text cells. Recommended values 0-50'
        end
        post :pdf do

          # pp params
          # pp declared(params)

          board = Boardbuilder::Board.accessible_by(current_ability).find(params[:id])

          options = {
            page_size: declared(params)[:pageSize][:name],
          }

          options[:page_layout]        = declared(params)[:orientation].to_sym  if declared(params).has_key? :orientation
          options[:font_size]          = declared(params)[:fontSize]            if declared(params).has_key? :fontSize
          options[:cell_padding]       = declared(params)[:cellPadding]         if declared(params).has_key? :cellPadding
          options[:cell_spacing]       = declared(params)[:cellSpacing]         if declared(params).has_key? :cellSpacing
          options[:draw_cell_borders]  = declared(params)[:drawCellBorders]     if declared(params).has_key? :drawCellBorders
          options[:image_text_spacing] = declared(params)[:imageTextSpacing]    if declared(params).has_key? :imageTextSpacing

          # pp options

          begin
            pdf = BoardBuilder::BoardToPdf.generate(board, options)
          rescue PdfGenerationException => e
            error!({
                     error: e.attributes,
                     code: 406,
                     with: GlobalSymbols::V1::Entities::Error
                   }, 406)
          end


          content_type 'application/pdf'
  
          header['Content-Disposition'] = declared(params)[:download] ? "attachment; filename=#{board.name}.pdf" : "inline"
  
          env['api.format'] = :binary
          body pdf.render
        end


        desc 'Reorders the Board\'s Cells'
        oauth2 'boardset:write'
        params do
          requires :cell_ids, type: Array[String], desc: 'Array of Cell IDs, in the new order', default: []
        end
        patch 'reorder_cells' do
          board = Boardbuilder::Board.accessible_by(current_ability).find(params[:id])
          authorize! :manage, board

          # Raises RecordNotFound if a cell_id isn't in the specified authorised board.
          cells = board.cells.find(params[:cell_ids])

          cells.each_with_index do |cell, index|
            cell.update(index: (index + 1))
          end
        end
      end
    end
  end
end
