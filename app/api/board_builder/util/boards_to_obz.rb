require 'open-uri'
require 'base64'

module BoardBuilder
    module Util
        module BoardsToObz
          # Builds the OBZ file map: a hash of { filename => content } representing
          # all files that would be zipped into the .obz archive.
          #
          # Options:
          #   embed_images: [Boolean] (default: false)
          #     When false (default): image entries carry a "url" pointing to the remote asset.
          #     When true: each image is downloaded and stored in the file map under
          #     "images/<image_id>.<ext>". The image entry uses "path" instead of "url",
          #     and the manifest paths.images map is populated accordingly.
          #     This produces a fully self-contained archive per the OBZ spec
          #     (§"path-based referencing").
          #
          # The spec requires:
          #   - Each board is a separate .obf file (JSON) stored at "boards/<id>"
          #   - A manifest.json at the root maps all board and image paths
          #   - manifest "root" points to the first (home) board path
          #   - All IDs must be strings (not integers)
          #   - load_board.path must point to the .obf path of the linked board
          def self.boards_to_obz_file_map(boards, embed_images: false)
            file_map        = {}
            gs_id_board_map = {}   # gs board.id  =>  obf board hash
            obf_id_path_map = {}   # obf board id =>  its path in the zip ("boards/xxx.obf")
            first_obf_path  = nil

            # First pass: build every .obf board and register its zip path
            boards.each do |board|
              obf_board = transform_board_to_obf(board)
              obf_path  = "boards/#{obf_board["id"]}"   # e.g. "boards/board-abc123-42.obf"

              first_obf_path = first_obf_path || obf_path

              gs_id_board_map[board.id]        = obf_board
              obf_id_path_map[obf_board["id"]] = obf_path
              file_map[obf_path]               = obf_board
            end

            # Build manifest.json
            # Spec: manifest root = path to root board; paths.boards maps id => path
            manifest = {
              "format" => "open-board-0.1",
              "root"   => first_obf_path,
              "paths"  => {
                "boards" => {},
                "images" => {},
                "sounds" => {}
              }
            }

            # Second pass: resolve load_board links, populate manifest, embed images if requested
            gs_id_board_map.each_value do |obf_board|
              obf_path = obf_id_path_map[obf_board["id"]]
              manifest["paths"]["boards"][obf_board["id"]] = obf_path

              obf_board["buttons"].each do |button|
                next if button["load_board"].blank?

                # load_board["id"] currently holds the GS integer board.id (set during
                # transform_board_to_obf). Resolve it to the linked OBF board now.
                linked_gs_id = button["load_board"]["id"]
                linked_obf   = gs_id_board_map[linked_gs_id]

                if linked_obf.present?
                  linked_path = obf_id_path_map[linked_obf["id"]]
                  # Spec: load_board must carry a string "id" and a "path" to the .obf
                  button["load_board"] = {
                    "id"   => linked_obf["id"],   # string OBF id, not the integer GS id
                    "path" => linked_path
                  }
                else
                  # Linked board not exported in this package — drop the unresolvable link
                  button.delete("load_board")
                end
              end

              # Optionally embed images: download each remote URL and store it as a file
              # in the zip, replacing "url" with "path" on the image entry.
              # Spec §"path-based referencing": images can be included in the zipped package
              # and referenced using the path attribute.
              if embed_images
                obf_board["images"].each do |image|
                  next if image["url"].blank?

                  image_path, image_data = download_image(image["id"], image["url"])
                  next if image_path.nil? || image_data.nil?

                  # Store the raw binary in the file map under its zip path
                  file_map[image_path]    = image_data
                  # Register in manifest
                  manifest["paths"]["images"][image["id"]] = image_path

                  # Replace "url" with "path" on the image entry (spec priority: path > url)
                  image["path"] = image_path
                  image.delete("url")
                end
              end
            end

            file_map["manifest.json"] = manifest
            file_map
          end

          # Converts a GS board (ActiveRecord object) to an OBF hash.
          #
          # Spec compliance:
          #   - All IDs are strings (spec §"Numerical IDs")
          #   - Empty cell slots are null in grid.order (spec §"Button Ordering")
          #   - Colors and labels only emitted when present (avoids null fields)
          #   - locale sourced from the parent board_set
          #
          # ATTENTION: load_board["id"] stores the GS integer board id at this stage.
          # It is resolved to a proper string OBF id by boards_to_obz_file_map.
          def self.transform_board_to_obf(gs_board)
            rows    = gs_board["rows"].to_i
            columns = gs_board["columns"].to_i

            obf = {
              "format"  => "open-board-0.1",
              "id"      => "#{generate_board_id(gs_board.id)}.obf",
              "name"    => gs_board["name"].to_s,
              "locale"  => gs_board.board_set.lang.presence || "en",
              "buttons" => [],
              "grid"    => {
                "rows"    => rows,
                "columns" => columns,
                # All slots start as null; filled in below (spec: unused slots must be null)
                "order"   => Array.new(rows) { Array.new(columns, nil) }
              },
              "images"  => []
            }

            # Sort cells by index for deterministic row/column positioning
            cells = gs_board.cells.sort_by { |c| c.index || 0 }.map(&:attributes)

            cells.each_with_index do |cell, index|
              row    = index / columns
              column = index % columns

              # Skip cells that fall outside the declared grid dimensions
              next unless row < rows && column < columns

              button_id = generate_button_id(cell["id"])
              button    = { "id" => button_id }

              # Spec: label omitted when blank so parsers receive no empty string
              button["label"] = cell["caption"] if cell["caption"].present?

              # Colors only emitted when set (spec allows omitting unset attributes)
              button["background_color"] = cell["background_colour"] if cell["background_colour"].present?
              button["border_color"]     = cell["border_colour"]     if cell["border_colour"].present?

              # Image reference: image_id on button + entry in images array
              if cell["image_url"].present?
                image_id = generate_image_id(cell["id"])
                button["image_id"] = image_id
                obf["images"] << {
                  "id"  => image_id,
                  "url" => cell["image_url"]
                }
              end

              # Board link — integer GS id, replaced with string OBF id in second pass
              if cell["linked_to_boardbuilder_board_id"].present?
                button["load_board"] = { "id" => cell["linked_to_boardbuilder_board_id"] }
              end

              obf["grid"]["order"][row][column] = button_id
              obf["buttons"] << button
            end

            obf
          end

          # Downloads an image from a remote URL and returns [zip_path, binary_data].
          # The zip path is "images/<image_id>.<ext>", where the extension is inferred
          # from the URL or falls back to "png".
          # Returns [nil, nil] on any network or HTTP error so callers can skip gracefully.
          def self.download_image(image_id, url)
            ext      = File.extname(URI.parse(url).path).delete_prefix(".").downcase
            ext      = "png" if ext.blank? || ext.length > 5   # guard against garbage extensions
            zip_path = "images/#{image_id}.#{ext}"

            data = URI.open(url, read_timeout: 10, open_timeout: 5, &:read) # rubocop:disable Security/Open
            [zip_path, data]
          rescue StandardError => e
            Rails.logger.warn "[BoardsToObz] Could not download image #{url}: #{e.message}"
            [nil, nil]
          end

          # ID generators
          # Spec: IDs must be strings and unique within the .obz package.
          # Combining a random hex segment with the GS record id guarantees both.

          def self.generate_board_id(gs_id)
            "board-#{SecureRandom.hex(6)}-#{gs_id}"
          end

          def self.generate_button_id(gs_cell_id)
            "btn-#{SecureRandom.hex(4)}-#{gs_cell_id}"
          end

          def self.generate_image_id(gs_cell_id)
            "img-#{SecureRandom.hex(4)}-#{gs_cell_id}"
          end

          private_class_method :transform_board_to_obf
          private_class_method :download_image
          private_class_method :generate_board_id
          private_class_method :generate_button_id
          private_class_method :generate_image_id
        end
    end
end
