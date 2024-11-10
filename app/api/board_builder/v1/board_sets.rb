module BoardBuilder::V1
  class BoardSets < Grape::API

    helpers SharedHelpers

    resource :board_sets do
      desc 'Returns BoardSets belonging to the current user',
        success: Entities::BoardSet,
        is_array: true
      params do
        use :expand
      end
      oauth2 'boardset:read'
      get do
        present current_user.boardbuilder_board_sets.accessible_by(current_ability), with: Entities::BoardSet, expand: params[:expand]
      end

      # FEATURED BOARDSETS
      desc 'Returns featured BoardSets',
           success: Entities::BoardSet,
           is_array: true
      params do
        use :expand
      end
      oauth2 'boardset:read'
      get :featured do
        present Boardbuilder::BoardSet.where.not(featured_level: nil).where(public: true).order(featured_level: :asc).order(name: :asc), with: Entities::BoardSet, expand: params[:expand], readonly: true, show_owner: true
      end
      # END FEATURED BOARDSETS

      route_param :id do
        desc 'Returns a specific BoardSet belonging to the current user',
             success: Entities::BoardSet,
             is_array: false
        params do
          requires :id, type: Integer, desc: 'BoardSet ID'
          use :expand
        end
        oauth2 'boardset:read'
        get do
          boardset = Boardbuilder::BoardSet.accessible_by(current_ability).find(params[:id])
          present boardset, with: Entities::BoardSet, expand: params[:expand], readonly: !(can? :manage, boardset)
        end


        desc 'Updates a BoardSet belonging to the current user',
             success: Entities::BoardSet,
             is_array: false
        params do
          optional :name, type: String, desc: 'BoardSet name'
          optional :public, type: Boolean, desc: 'Public visibility'
          optional :opened_at, type: DateTime, desc: 'Date BoardSet was last opened'
        end
        oauth2 'boardset:write'
        patch do
          board_set = Boardbuilder::BoardSet.accessible_by(current_ability).find(params[:id])
          authorize! :manage, board_set
          board_set.update!(declared(params, include_missing: false))
          present board_set, with: Entities::BoardSet
        end


        desc 'Destroys a BoardSet belonging to the current user'
        oauth2 'boardset:write'
        delete do
          board_set = Boardbuilder::BoardSet.accessible_by(current_ability).find(params[:id])
          authorize! :manage, board_set
          board_set.destroy!
          present nil
        end
      end


      desc 'Creates a BoardSet belonging to the current user',
        success: Entities::BoardSet

      params do
        requires :name, type: String, desc: 'BoardSet name'

        optional :boards, as: :boards_attributes, type: Array[JSON] do
          requires :name, type: String, desc: 'Board name'
          optional :description, type: String, desc: 'Board description'
          optional :columns, type: Integer
          optional :rows, type: Integer
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

      end
      oauth2 'boardset:write'
      post do
        board_set = Boardbuilder::BoardSet.new(declared(params, include_missing: false))
        board_set.users << resource_owner
        board_set.save!
        present board_set, with: Entities::BoardSet, expand: 'boards'
      end



    end
  end
end