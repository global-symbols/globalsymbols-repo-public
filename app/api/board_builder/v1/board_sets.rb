module BoardBuilder::V1
  class BoardSets < Grape::API

    require_relative '../util/obz_to_boards'
    require 'json'

    helpers SharedHelpers

    resource :board_sets do

      desc 'Returns public BoardSets',
           success: Entities::BoardSet,
           is_array: true
      params do
        use :expand
        optional :search, type: String, desc: 'search term searching for author, name, tags'
        optional :lang, type: String, desc: 'preferred language'
        optional :self_contained, type: Boolean, desc: 'false if searching for single boards, true if searching for full self-contained communicators'
      end
      get :public do
        query = Boardbuilder::BoardSet.where(public: true)
        if !params[:search].blank?
          search_term = ActiveRecord::Base.sanitize_sql_like(params[:search])
          query = query.where(['author LIKE :search OR name LIKE :search OR CAST(tags AS CHAR) LIKE :search', search: "%#{search_term}%"])
        end
        if !params[:lang].blank?
          query = query.where(['lang LIKE ? OR lang IS NULL', "%#{params[:lang]}%"])
        end
        if !params[:self_contained].nil?
          query = query.where(self_contained: params[:self_contained])
        end
        present query.order(lang: :desc, download_count: :desc, name: :asc).limit(100), with: Entities::BoardSet, expand: params[:expand], readonly: true
      end

      desc 'Returns a specific public BoardSet',
           success: Entities::BoardSet,
           is_array: false
      params do
        requires :id, type: Integer, desc: 'ID of the BoardSet'
        use :expand
      end
      get 'public/:id' do
        board_set = Boardbuilder::BoardSet.where(id: params[:id], public: true).first
        if !board_set.blank?
          board_set.download_count += 1
          board_set.save!
        end
        present board_set, with: Entities::BoardSet, expand: params[:expand], readonly: true, show_owner: true
      end

      desc 'Returns a specific public BoardSet in OBZ format',
           success: Entities::BoardSetObz,
           is_array: false
      params do
        requires :id, type: Integer, desc: 'ID of the BoardSet'
      end
      get 'public/obz/:id' do
        board_set = Boardbuilder::BoardSet.includes(boards: :cells).where(id: params[:id], public: true).first
        if !board_set.blank?
          board_set.download_count += 1
          board_set.save!
        end
        present board_set, with: Entities::BoardSetObz
      end

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
          boardset = Boardbuilder::BoardSet.accessible_by(current_ability)
                                           .includes(boards: :cells)
                                           .find(params[:id])
          present boardset, with: Entities::BoardSet, expand: params[:expand], readonly: !(can? :manage, boardset), boards_with_cells: boardset.boards
        end


        desc 'Updates a BoardSet belonging to the current user',
             success: Entities::BoardSet,
             is_array: false
        params do
          optional :name, type: String, desc: 'BoardSet name'
          optional :public, type: Boolean, desc: 'Public visibility'
          optional :description, type: String, desc: 'Short description of the BoardSet'
          optional :author, type: String, desc: 'Author of the BoardSet'
          optional :author_url, type: String, desc: 'Homepage of the author'
          optional :tags, type: Array[String], desc: 'Tags for this BoardSet'
          optional :self_contained, type: Boolean, desc: 'true if BoardSet is self-contained'
          optional :lang, type: String, desc: 'Language of the BoardSet'
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

        optional :boards, type: Array[JSON] do
          requires :name, type: String, desc: 'Board name'
          optional :description, type: String, desc: 'Board description'
          optional :columns, type: Integer
          optional :rows, type: Integer
          optional :captions_position, type: String, desc: 'Default caption position within Cells', default: 'below'

          optional :cells, type: Array[JSON] do
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
        filtered_params = declared(params, include_missing: false)
        board_set = save_board_set(filtered_params)
        present board_set, with: Entities::BoardSet, expand: 'boards'
      end

      desc 'Creates a BoardSet belonging to the current user, data passed in OBZ format',
           success: Entities::BoardSet
      params do
        requires :name, type: String, desc: 'BoardSet name'
        # obz_file_map has to be passed as String (e.g. JSON.stringify) with type: String here,
        # because type: Hash results in weird representation of the board.grid.order array of arrays of obf
        requires :obz_file_map, type: String, desc: 'a JSON string containing a map of all files of the OBZ, [filename => file_content]. OBF files are JSON, images are base64 encoded.'
        optional :description, type: String, desc: 'Description of the board set'
        optional :tags, type: Array[String], desc: 'array of tags for this board set'
        optional :lang, type: String, desc: 'Two digit code of the language of the boardset. Defaults to language of Global Symbols user'
        optional :author, type: String, desc: 'BoardSet author'
        optional :author_url, type: String, desc: 'BoardSet author URL'
        optional :self_contained, type: Boolean, desc: 'true, if board set is a self contained configuration, false if just single boards'
        optional :public, type: Boolean, desc: 'true, if board set is public'
        optional :thumbnail, type: String, desc: 'Thumbnail image as base64 data string. SVG, JPG or PNG.'
      end
      oauth2 'boardset:write'
      post :obz do
        filtered_params = declared(params, include_missing: false)
        obz_file_map = JSON.parse(filtered_params[:obz_file_map])
        saved_images = save_images(obz_file_map, return_media: true)

        boards = ObzToBoards.obz_file_map_to_gs_boards(obz_file_map, saved_images)

        thumbnail = nil
        if !filtered_params[:thumbnail].blank?
          thumbnail = save_image(filtered_params[:thumbnail], resize_image_width: 800, resize_image_height: 600)
        end

        filtered_params[:boards] = boards
        filtered_params[:thumbnail] = thumbnail
        filtered_params.delete(:obz_file_map)
        board_set = save_board_set(filtered_params)
        present board_set, with: Entities::BoardSet, expand: 'boards'
      end
    end
  end
end