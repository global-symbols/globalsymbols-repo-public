module BoardBuilder
    module Util
        module ObzToBoards
          extend Grape::API::Helpers
          # transforms an obz_file_map to an array of globalsymbols boards
          # note: for linked cells "linked_to_obf_id" contains the "obf_id" of the linked board, which is also preserved within
          # the returned gs_board. This connection has to be resolved at saving, creating the correct linking by setting
          # "linked_to_boardbuilder_board_id" to the actual ID after saving gs_board to the database. "obf_id" and "linked_to_obf_id"
          # should be removed afterwards
          # media_map is a map [filename -> media] which are used for filling correct urls and media references
          def self.obz_file_map_to_gs_boards (obz_file_map, media_map = {})
            obf_files = obz_file_map.select { |filename, _| filename.end_with?(".obf") }
            obf_id_to_obf = {}
            gs_boards = []

            obf_files.each_value do |obf_board|
              obf_id_to_obf[obf_board["id"]] = obf_board
              gs_boards << transform_obf_to_board(obf_board, media_map)
            end

            # transform load_board.path attributes to actual id of linked board
            gs_boards.each do |board|
              board["cells"].each do |cell|
                if !cell["linked_to_obf_id"].blank?
                  obf = obz_file_map[cell["linked_to_obf_id"]]
                  if obf.blank?
                    cell.delete("linked_to_obf_id")
                  else
                    cell["linked_to_obf_id"] = obf["id"]
                  end
                end
              end
            end

            gs_boards
          end

          def self.transform_obf_to_board(obf_board, media_map = {})
            cells = obf_board["grid"]["order"].flatten.map.with_index do |element_id, index|
              button = obf_board["buttons"]&.find { |btn| btn["id"] == element_id } || {}
              image = obf_board["images"]&.find { |img| img["id"] == button&.dig("image_id") } || {}
              image_url = image.blank? ? nil : (image["url"] || media_map[image["path"]]&.file&.url)
              link_path = button&.dig("load_board", "path")
              {
                "linked_to_obf_id" => link_path,
                "caption" => button["label"].blank? ? nil : button["label"],
                "index" => index,
                "image_url" => image_url,
                "boardbuilder_media_id" => media_map[image["path"]]&.id,
                "background_colour" => button["background_color"]
              }
            end
            gs_board = {
              "obf_id" => obf_board["id"],
              "name" => obf_board["name"],
              "columns" => obf_board["grid"]["columns"],
              "rows" => obf_board["grid"]["rows"],
              "cells" => cells
            }

            gs_board
          end

          private_class_method :transform_obf_to_board
        end
    end
end
