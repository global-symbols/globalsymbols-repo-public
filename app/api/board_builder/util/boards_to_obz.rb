module BoardsToOBZ
  def self.boards_to_obz_file_map (boards)
    file_map = {}
    gs_id_board_map = {}
    first_obf_board = nil

    boards.each do |board|
      obf_board = transform_board_to_obf(board)
      first_obf_board = first_obf_board || obf_board
      gs_id_board_map[board.id] = obf_board
      file_map[obf_board["id"]] = obf_board
    end

    manifest = {
      "format" => "open-board-0.1",
      "root" => first_obf_board["id"],
      "paths" => {
        "boards" => {},
        "images" => {},
        "sounds" => {}
      }
    }

    gs_id_board_map.each_value do |obf_board|
      manifest["paths"]["boards"][obf_board["id"]] = obf_board["id"]
      obf_board["buttons"].each do |button|
        if !button["load_board"].blank?
          linked_obf = gs_id_board_map[button["load_board"]["id"]]
          if !linked_obf.blank?
            button["load_board"]["id"] = linked_obf["id"]
            button["load_board"]["path"] = linked_obf["id"]
          else
            button.delete("load_board")
          end
        end
      end
    end
    file_map["manifest.json"] = manifest
    file_map
  end

  # converts a board from global symbols to obf format
  # attention: load_board.id attribute is the actual id of the gs_board and
  # has to be converted to the correct id/path afterwards
  def self.transform_board_to_obf(gs_board)
    obf_in_json = {
      "format" => "open-board-0.1",
      "id" => "#{generate_unique_id("board", gs_board.id)}.obf",
      "name" => gs_board["name"],
      "buttons" => [],
      "grid" => {
        "rows" => gs_board["rows"],
        "columns" => gs_board["columns"],
        "order" => Array.new(gs_board["rows"]) { Array.new(gs_board["columns"]) }
      },
      "images" => []
    }

    cells = gs_board.cells.map(&:attributes)
    cells.each_with_index do |cell, index|
      button_id = self.generate_unique_id("button", cell["id"])
      image_id = self.generate_unique_id("image", cell["id"])

      button = {
        "id" => button_id,
        "label" => cell["caption"],
        "background_color" => cell["background_colour"]
      }

      if !cell["image_url"].blank?
        button["image_id"] = image_id
        obf_in_json["images"] << {
          "id" => image_id,
          "url" => cell["image_url"]
        }
      end

      if !cell["linked_to_boardbuilder_board_id"].blank?
        button["load_board"] = {
          "id" => cell["linked_to_boardbuilder_board_id"]
        }
      end

      row = index / gs_board["columns"]
      column = index % gs_board["columns"]
      if row < obf_in_json["grid"]["rows"] and column < obf_in_json["grid"]["columns"]
        obf_in_json["grid"]["order"][row][column] = button_id
        obf_in_json["buttons"] << button
      end
    end
    obf_in_json
  end

  def self.generate_unique_id(prefix, postfix = "0")
    "#{prefix}-#{SecureRandom.random_number(10**10)}#{postfix}"
  end

  private_class_method :transform_board_to_obf
  private_class_method :generate_unique_id
end