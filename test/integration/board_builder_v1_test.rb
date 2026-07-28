# frozen_string_literal: true

require 'test_helper'

class BoardBuilderV1Test < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @token = create(:doorkeeper_token, :with_boardbuilder_scopes)
    @user = User.find(@token.resource_owner_id)
    @headers = { 'Authorization' => "Bearer #{@token.token}" }
  end

  # --- Board sets ---

  test 'GET /api/boardbuilder/v1/board_sets requires authentication' do
    get '/api/boardbuilder/v1/board_sets'

    assert_response :unauthorized
  end

  test 'GET /api/boardbuilder/v1/board_sets returns board sets for authenticated user' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    other_set = create(:board_set, boards_count: 1)

    get '/api/boardbuilder/v1/board_sets', headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    names = body.map { |row| row['name'] }
    assert_includes names, board_set.name
    refute_includes names, other_set.name
  end

  test 'GET /api/boardbuilder/v1/board_sets/:id returns owned board set' do
    board_set = create(:board_set, owner: @user, boards_count: 1)

    get "/api/boardbuilder/v1/board_sets/#{board_set.id}", headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal board_set.id, body['id']
    assert_equal board_set.name, body['name']
    assert_equal false, body['readonly']
  end

  test 'GET /api/boardbuilder/v1/board_sets/:id expands boards' do
    board_set = create(:board_set, owner: @user, boards_count: 1)

    get "/api/boardbuilder/v1/board_sets/#{board_set.id}",
        params: { expand: 'boards' },
        headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert body['boards'].is_a?(Array)
    assert_includes body['boards'].map { |row| row['id'] }, board_set.boards.first.id
  end

  test 'GET /api/boardbuilder/v1/board_sets/:id returns readonly for public board set owned by another user' do
    public_set = create(:board_set, boards_count: 1, public: true)

    get "/api/boardbuilder/v1/board_sets/#{public_set.id}", headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal public_set.id, body['id']
    assert_equal true, body['readonly']
  end

  test 'GET /api/boardbuilder/v1/board_sets/:id returns not found for private board set owned by another user' do
    private_set = create(:board_set, boards_count: 1, public: false)

    get "/api/boardbuilder/v1/board_sets/#{private_set.id}", headers: @headers

    assert_response :not_found
  end

  test 'PATCH /api/boardbuilder/v1/board_sets/:id updates owned board set' do
    board_set = create(:board_set, owner: @user, boards_count: 0)

    patch "/api/boardbuilder/v1/board_sets/#{board_set.id}",
          params: { name: 'Updated Board Set' },
          headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 'Updated Board Set', body['name']
    assert_equal 'Updated Board Set', board_set.reload.name
  end

  test 'PATCH /api/boardbuilder/v1/board_sets/:id returns forbidden for public board set owned by another user' do
    public_set = create(:board_set, boards_count: 0, public: true)
    original_name = public_set.name

    patch "/api/boardbuilder/v1/board_sets/#{public_set.id}",
          params: { name: 'Should Not Update' },
          headers: @headers

    assert_response :forbidden
    assert_equal original_name, public_set.reload.name
  end

  test 'DELETE /api/boardbuilder/v1/board_sets/:id destroys owned board set' do
    board_set = create(:board_set, owner: @user, boards_count: 0)

    assert_difference('Boardbuilder::BoardSet.count', -1) do
      delete "/api/boardbuilder/v1/board_sets/#{board_set.id}", headers: @headers
    end

    assert_response :no_content
  end

  test 'POST /api/boardbuilder/v1/board_sets creates a board set for authenticated user' do
    assert_difference('Boardbuilder::BoardSet.count', 1) do
      post '/api/boardbuilder/v1/board_sets',
           params: { name: 'New Board Set' },
           headers: @headers
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal 'New Board Set', body['name']

    board_set = Boardbuilder::BoardSet.find(body['id'])
    assert_equal @user, board_set.board_set_users.find_by(role: :owner).user
  end

  test 'POST /api/boardbuilder/v1/board_sets creates nested boards and cells' do
    params = {
      name: 'Nested Board Set',
      boards: [{
        name: 'First Board',
        rows: 1,
        columns: 2,
        cells: [
          { caption: 'First Cell' },
          { caption: 'Second Cell' }
        ]
      }]
    }

    assert_difference('Boardbuilder::BoardSet.count', 1) do
      assert_difference('Boardbuilder::Board.count', 1) do
        assert_difference('Boardbuilder::Cell.count', 2) do
          post '/api/boardbuilder/v1/board_sets', params: params, headers: @headers
        end
      end
    end

    assert_response :created
    board = Boardbuilder::Board.last
    assert_equal ['First Cell', 'Second Cell'], board.cells.order(:index).pluck(:caption)
  end

  test 'GET /api/boardbuilder/v1/board_sets/featured returns public featured board sets' do
    featured = create(:board_set, public: true, featured_level: 1, boards_count: 0)
    create(:board_set, public: false, featured_level: 1, boards_count: 0)
    create(:board_set, public: true, featured_level: nil, boards_count: 0)

    get '/api/boardbuilder/v1/board_sets/featured', headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    ids = body.map { |row| row['id'] }
    assert_includes ids, featured.id
    assert(body.all? { |row| row['readonly'] == true })
  end

  test 'GET /api/boardbuilder/v1/board_sets/public returns public board sets without authentication' do
    public_set = create(:board_set, public: true, boards_count: 0)
    create(:board_set, public: false, boards_count: 0)

    get '/api/boardbuilder/v1/board_sets/public'

    assert_response :success
    body = JSON.parse(response.body)
    ids = body.map { |row| row['id'] }
    assert_includes ids, public_set.id
  end

  test 'GET /api/boardbuilder/v1/board_sets/public/:id returns a public board set without authentication' do
    public_set = create(:board_set, public: true, boards_count: 1)

    get "/api/boardbuilder/v1/board_sets/public/#{public_set.id}"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal public_set.id, body['id']
    assert_equal public_set.name, body['name']
  end

  # --- Boards ---

  test 'boards index requires authentication' do
    board_set = create(:board_set, owner: @user, boards_count: 1)

    get '/api/boardbuilder/v1/boards', params: { board_set_id: board_set.id }

    assert_response :unauthorized
  end

  test 'boards index returns boards for authenticated user' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    board = board_set.boards.first

    get '/api/boardbuilder/v1/boards',
        params: { board_set_id: board_set.id },
        headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    board_ids = body.map { |row| row['id'] }
    assert_includes board_ids, board.id
  end

  test 'board show returns board details' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    board = board_set.boards.first

    get "/api/boardbuilder/v1/boards/#{board.id}", headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal board.name, body['name']
  end

  test 'board show expands cells' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    board = board_set.boards.first

    get "/api/boardbuilder/v1/boards/#{board.id}",
        params: { expand: 'cells' },
        headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert body['cells'].is_a?(Array)
    assert_includes body['cells'].map { |row| row['id'] }, board.cells.first.id
  end

  test 'board show returns not found for board owned by another user' do
    other_board = create(:board_set, boards_count: 1).boards.first

    get "/api/boardbuilder/v1/boards/#{other_board.id}", headers: @headers

    assert_response :not_found
  end

  test 'PATCH /api/boardbuilder/v1/boards/:id updates owned board' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    board = board_set.boards.first

    patch "/api/boardbuilder/v1/boards/#{board.id}",
          params: { name: 'Renamed Board' },
          headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 'Renamed Board', body['name']
    assert_equal 'Renamed Board', board.reload.name
  end

  test 'DELETE /api/boardbuilder/v1/boards/:id destroys owned board and cells' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    board = board_set.boards.first
    cell_count = board.cells.count

    assert_difference('Boardbuilder::Board.count', -1) do
      assert_difference('Boardbuilder::Cell.count', -cell_count) do
        delete "/api/boardbuilder/v1/boards/#{board.id}", headers: @headers
      end
    end

    assert_response :no_content
  end

  test 'POST /api/boardbuilder/v1/boards creates a board with cells' do
    board_set = create(:board_set, owner: @user, boards_count: 0)
    params = {
      board_set_id: board_set.id,
      name: 'New Board',
      rows: 1,
      columns: 2,
      cells: [
        { caption: 'First Cell' },
        { caption: 'Second Cell' }
      ]
    }

    assert_difference('Boardbuilder::Board.count', 1) do
      assert_difference('Boardbuilder::Cell.count', 2) do
        post '/api/boardbuilder/v1/boards', params: params, headers: @headers
      end
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal 'New Board', body['name']
  end

  test 'PATCH /api/boardbuilder/v1/boards/:id/reorder_cells reorders cells' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    board = board_set.boards.first
    original_order = board.cells.order(index: :asc).pluck(:id)
    reversed_order = board.cells.order(index: :desc).pluck(:id)

    patch "/api/boardbuilder/v1/boards/#{board.id}/reorder_cells",
          params: { cell_ids: reversed_order },
          headers: @headers

    assert_response :success
    assert_equal reversed_order, board.cells.reload.order(index: :asc).pluck(:id)
    refute_equal original_order, reversed_order
  end

  test 'POST /api/boardbuilder/v1/boards/:id/pdf returns a PDF' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    board = board_set.boards.first

    post "/api/boardbuilder/v1/boards/#{board.id}/pdf",
         params: {
           skipImages: true,
           orientation: 'portrait',
           pageSize: { name: 'A4' },
           cellPadding: 10,
           cellSpacing: 10,
           fontSize: 12,
           imageTextSpacing: 5
         },
         headers: @headers

    assert_response :success
    assert_equal 'application/pdf', response.media_type
    assert_operator response.body.bytesize, :>, 100
  end

  test 'POST /api/boardbuilder/v1/boards/obf imports an OBF board' do
    board_set = create(:board_set, owner: @user, boards_count: 0)
    obf = JSON.parse(File.read(Rails.root.join('test/fixtures/obf_with_embedded_base64_images.obf')))

    assert_difference('Boardbuilder::Board.count', 1) do
      post '/api/boardbuilder/v1/boards/obf',
           params: { obf: obf, board_set_id: board_set.id },
           headers: @headers
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal board_set.id, body['board_set_id']
  end

  # --- Cells ---

  test 'GET /api/boardbuilder/v1/cells returns cells for owned board' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    board = board_set.boards.first

    get '/api/boardbuilder/v1/cells',
        params: { board_id: board.id },
        headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal board.rows * board.columns, body.length
    assert_includes body.map { |row| row['id'] }, board.cells.first.id
  end

  test 'GET /api/boardbuilder/v1/cells/:id returns owned cell' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    cell = board_set.boards.first.cells.first

    get "/api/boardbuilder/v1/cells/#{cell.id}", headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal cell.id, body['id']
    if cell.caption.nil?
      assert_nil body['caption']
    else
      assert_equal cell.caption, body['caption']
    end
  end

  test 'GET /api/boardbuilder/v1/cells/:id returns not found for cell owned by another user' do
    other_cell = create(:board_set, boards_count: 1).boards.first.cells.first

    get "/api/boardbuilder/v1/cells/#{other_cell.id}", headers: @headers

    assert_response :not_found
  end

  test 'PATCH /api/boardbuilder/v1/cells/:id updates owned cell' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    cell = board_set.boards.first.cells.first

    patch "/api/boardbuilder/v1/cells/#{cell.id}",
          params: { caption: 'Updated Caption' },
          headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 'Updated Caption', body['caption']
    assert_equal 'Updated Caption', cell.reload.caption
  end

  test 'DELETE /api/boardbuilder/v1/cells/:id is not allowed' do
    board_set = create(:board_set, owner: @user, boards_count: 1)
    cell = board_set.boards.first.cells.first

    assert_no_difference('Boardbuilder::Cell.count') do
      delete "/api/boardbuilder/v1/cells/#{cell.id}", headers: @headers
    end

    assert_response :method_not_allowed
  end

  # --- Media ---

  test 'GET /api/boardbuilder/v1/media requires authentication' do
    get '/api/boardbuilder/v1/media'

    assert_response :unauthorized
  end

  test 'GET /api/boardbuilder/v1/media returns paginated media for authenticated user' do
    owned = create(:media, user: @user, caption: 'Owned Media')
    create(:media, caption: 'Unowned Media')

    get '/api/boardbuilder/v1/media', headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert body['items'].is_a?(Array)
    assert body['total'].is_a?(Integer)
    captions = body['items'].map { |row| row['caption'] }
    assert_includes captions, owned.caption
    refute_includes captions, 'Unowned Media'
  end

  test 'GET /api/boardbuilder/v1/media/:id returns owned media' do
    media = create(:media, user: @user, caption: 'My Media')

    get "/api/boardbuilder/v1/media/#{media.id}", headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal media.id, body['id']
    assert_equal @user.id, body['user_id']
    assert_equal 'My Media', body['caption']
  end

  test 'GET /api/boardbuilder/v1/media/:id returns not found for media owned by another user' do
    other_media = create(:media, caption: 'Other Media')

    get "/api/boardbuilder/v1/media/#{other_media.id}", headers: @headers

    assert_response :not_found
  end

  test 'POST /api/boardbuilder/v1/media creates media for authenticated user' do
    upload = Rack::Test::UploadedFile.new(
      Rails.root.join('test/fixtures/picto.image.imagefile.png'),
      'image/png'
    )

    assert_difference('Boardbuilder::Media.count', 1) do
      post '/api/boardbuilder/v1/media',
           params: { file: upload },
           headers: @headers
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal @user.id, body['user_id']
    assert body['public_url'].is_a?(String)
  end

  test 'PATCH /api/boardbuilder/v1/media/:id updates owned media' do
    media = create(:media, user: @user, caption: 'Before')

    patch "/api/boardbuilder/v1/media/#{media.id}",
          params: { caption: 'After' },
          headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 'After', body['caption']
    assert_equal 'After', media.reload.caption
  end

  test 'DELETE /api/boardbuilder/v1/media/:id destroys owned media' do
    media = create(:media, user: @user)

    assert_difference('Boardbuilder::Media.count', -1) do
      delete "/api/boardbuilder/v1/media/#{media.id}", headers: @headers
    end

    assert_response :no_content
  end

  # --- Search, templates, AI ---

  test 'search endpoint returns noun project results without authentication' do
    get '/api/boardbuilder/v1/symbols/search',
        params: { query: 'dog', source: 'the-noun-project' }

    assert_response :success
    body = JSON.parse(response.body)
    assert body.is_a?(Array)
    assert(body.any? { |row| row['label'].to_s.include?('Dog') })
  end

  test 'search endpoint returns success for authenticated user' do
    get '/api/boardbuilder/v1/symbols/search',
        params: { query: 'dog', source: 'the-noun-project' },
        headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert body.is_a?(Array)
  end

  test 'GET /api/boardbuilder/v1/templates/page_sizes returns paper sizes' do
    get '/api/boardbuilder/v1/templates/page_sizes', headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert body.is_a?(Array)
    assert body.any? { |row| row['name'] == 'A4' }
  end

  test 'GET /api/boardbuilder/v1/ai/health returns healthy status' do
    get '/api/boardbuilder/v1/ai/health'

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 'healthy', body['status']
  end
end