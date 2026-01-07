module BoardBuilder

  # Adds a fill-opacity='1' attribute to all <image> tags.
  # This overrides style="fill-opacity: 0" in <image> tags, which prevents correct rendering in PDFs.
  class AddFillOpacityToImages < SvgOptimizer::Plugins::Base
    def process
      xml.css('image').each do |node|
        # If the node has a style attribute, and the style attribute has a fill-opacity...
        if node['style'] and node['style'].include? 'fill-opacity'
          # Add a fill-opacity attribute on the node, which overrides the setting in the style attr.
          node['fill-opacity'] = '1'
        end
      end
    end
  end

  class BoardToPdf

    # AddFillOpacityToImages: Fixes images produced by FabricJS (Symbol Creator)
    # RemoveEditorNamespace:  Seems like a good idea. Not required.
    # RemoveUnusedNamespace:  Fixes SVGs from OpenSymbols.
    SVG_CLEANER_PLUGINS = [
      AddFillOpacityToImages,
      SvgOptimizer::Plugins::RemoveUnusedNamespace,
      # SvgOptimizer::Plugins::RemoveEditorNamespace  # Removed - causes namespace parsing errors
    ]
    # SVG_CLEANER_PLUGINS = SvgOptimizer::DEFAULT_PLUGINS + [AddFillOpacityToImages]

    def self.no_hash(string)
      string.sub '#', '' if string
    end
    
    def self.generate(board, options = {})

      start_time = Time.now
      image_load_count = 0
      image_error_count = 0
      Rails.logger.info("Starting PDF generation for board #{board.id} (#{board.name}) with #{board.cells.count} cells, #{board.rows}x#{board.columns} grid")

      allowed_svg_mime_types = ['image/svg+xml']
      allowed_raster_mime_types = ['image/jpeg', 'image/png']

      logo_svg_path = Rails.root.join('app', 'assets', 'images', 'board_builder', 'pdf-header-logo.svg')
      
      options = {
        page_size: 'A4',
        page_layout: (board.rows > board.columns ? :portrait : :landscape),
        draw_cell_borders: true,
        cell_border_width: 1,
        cell_padding: 10,
        cell_spacing: 10,
        image_text_spacing: -1, # -1 means 'auto'
        font_size: 12,
        default_border_colour: '000000',
        default_text_colour: '000000',
        default_background_colour: 'ffffff',
        caption_overflow: :shrink_to_fit,
        show_header: true,
        debug: false,
        skip_images: false  # For debugging: skip all image loading to test PDF structure
      }.merge options

      # Auto image/text spacing is half the specified cell padding.
      options[:image_text_spacing] = options[:cell_padding] / 2 if options[:image_text_spacing] == -1
      
      metadata = {
        Title:        board.name,
        # Title:        rand.to_s,
        Author:       '',
        Subject:      'A Board created with Global Symbols Board Builder',
        Keywords:     '',
        Creator:      'Global Symbols Board Builder',
        Producer:     'Global Symbols Board Builder',
        CreationDate: Time.now
      }

      # pp options

      prawn_doc = Prawn::Document.new page_size: options[:page_size],
                                      page_layout: options[:page_layout],
                                      compress: false,
                                      info: metadata,
                                      print_scaling: :none do

        # Fallback fonts must be listed here in order of preference.
        # When a glyph is missing from the default font, Prawn will look through the list until it finds a font
        # supporting the glyph.
        # We are using SourceHanSans, which is actually the source font for Google's Noto. Specifically, we're
        # using a TTF version because Prawn has trouble rendering the glyphs of OTF versions.
        # https://github.com/be5invis/source-han-sans-ttf
        fallback_fonts_list = {
          'SourceHanSans' => {
            normal: Rails.root.join('app/assets/fonts/SourceHanSans-Regular.ttf')
          },
          'NotoSans' => {
            normal: Rails.root.join('app/assets/fonts/NotoSans-Regular.ttf')
          },
          'NotoSansEthiopic' => {
            normal: Rails.root.join('app/assets/fonts/NotoSansEthiopic-Regular.ttf')
          },
          'NotoSerifThai' => {
            normal: Rails.root.join('app/assets/fonts/NotoSerifThai-Regular.ttf')
          },
          'NotoSansBengali' => {
            normal: Rails.root.join('app/assets/fonts/NotoSansBengali-Regular.ttf')
          },
          'NotoSansDevanagari' => {
            normal: Rails.root.join('app/assets/fonts/NotoSansDevanagari-Regular.ttf')
          },
          'NotoSansLao' => {
            normal: Rails.root.join('app/assets/fonts/NotoSansLao-Regular.ttf')
          }
        }

        font_families.update({
          'Arial utf8' => {
            normal: Rails.root.join('app/assets/fonts/Arial-Regular.ttf')
          }
        }.merge(fallback_fonts_list))

        # Use Arial for all text. When a glyph is missing from Arial, look for it in the fallback_fonts_list
        font 'Arial utf8'
        fallback_fonts fallback_fonts_list.keys


        header_height = 32    # Height of the inside of the header box
        header_spacing = 20   # Vertical spacing between the header and the cell grid

        cell_grid_y_pos = options[:show_header] ? bounds.height - header_height - header_spacing : bounds.height
        cell_grid_height = cell_grid_y_pos

        ordered_cells = board.cells.order(index: :asc, id: :asc)

        # Circuit breaker: if too many cells have images and we're dealing with a large board,
        # log a warning about potential performance issues
        cells_with_images = ordered_cells.select { |cell| cell.image_url.present? }.count
        if cells_with_images > 20
          Rails.logger.warn("Board #{board.id} has #{cells_with_images} cells with images - this may cause performance issues")
        end

        if options[:show_header]
          bounding_box([0, bounds.height], width: bounds.width, height: header_height) do
            define_grid(rows: 1, columns: 3, gutter: 20)

            # grid.show_all

            grid(0,0).bounding_box do

              if board.header_media
                begin
                  Rails.logger.debug("Loading header image for board #{board.id}")
                  header_image_start = Time.now
                  header_image = Faraday.get(URI.encode(board.header_media.file.url)) do |req|
                    req.options.timeout = 15        # 15 second timeout
                    req.options.open_timeout = 5    # 5 second connection timeout
                  end
                  header_image_load_time = Time.now - header_image_start
                  image_load_count += 1
                  Rails.logger.debug("Header image loaded in #{header_image_load_time.round(2)}s for board #{board.id}")

                  header_image_type = header_image.headers['content-type']

                  if header_image_type.in? allowed_svg_mime_types

                    # For some reason, images embedded with SVGs are rendered at the wrong size/position,
                    # UNLESS we pass the SVG through SvgOptimizer first.
                    svg SvgOptimizer.optimize(header_image.body, SVG_CLEANER_PLUGINS),
                        height: header_height,
                        position: :left,
                        enable_web_requests: true

                  elsif header_image_type.in? allowed_raster_mime_types
                    # Images supplied to Prawn must respond to 'read' and 'rewind'
                    # so we use StringIO.
                    image StringIO.new(header_image.body),
                          position: :left,
                          vposition: :center,
                          fit: [bounds.width, header_height]
                  end

                rescue Faraday::Error => e
                  image_error_count += 1
                  Rails.logger.warn("Failed to load header image for board #{board.id}: #{e.message}")
                  text 'Could not load header image'
                end

              end


            end

            grid(0,1).bounding_box do
              text board.name,
                   size: 24,
                   align: :center,
                   valign: :center,
                   overflow: :shrink_to_fit
            end

            grid(0,2).bounding_box do
              text board.description,
                   size: 12,
                   align: :right,
                   valign: :center,
                   overflow: :shrink_to_fit
            end

            grid([0,5], [0,7]).bounding_box do
            end

          end
        end

        bounding_box([0, cell_grid_y_pos], width: bounds.width, height: cell_grid_height) do

          define_grid(columns: board.columns, rows: board.rows, gutter: options[:cell_spacing])

          board.rows.times do |row|
            board.columns.times do |col|
              cell = ordered_cells[board.columns*row+col]
              grid(row, col).bounding_box do

                cell_inner_height = bounds.height - options[:cell_padding] * 2
                cell_inner_width = bounds.width - options[:cell_padding] * 2

                move_down options[:cell_padding]

                # Images should fill the height and width of the Cell
                image_height = cell_inner_height
                image_width = cell_inner_width

                caption_height = 0
                caption_width = cell_inner_width

                # If there's a caption above or below...
                if ['above', 'below'].include?(board.captions_position) and cell.caption
                  # ...deduct the text height and a spacer
                  caption_height = options[:font_size]
                  image_height = cell_inner_height - caption_height - options[:image_text_spacing]
                end

                # If the captions are left or right, halve the width of images and captions and set caption height to full
                if ['left', 'right'].include?(board.captions_position) and cell.caption
                  image_width   = (cell_inner_width / 2) - options[:image_text_spacing]

                  caption_width = (cell_inner_width / 2)# + options[:image_text_spacing]
                  caption_height = cell_inner_height
                end

                # The image should be positioned at the top of the cell
                image_y = bounds.height - options[:cell_padding]

                # ...and on the left
                image_x = options[:cell_padding]

                caption_x = options[:cell_padding]
                caption_y = caption_height + options[:cell_padding]

                # ...unless there's a caption to be shown at the top
                if board.captions_position == 'above' and cell.caption
                  # ...in which case, we deduct the text height and a spacer
                  image_y -= caption_height + options[:image_text_spacing]

                  caption_y = bounds.height - options[:cell_padding]
                end

                # If the caption is going on the left, move the image to the right
                if board.captions_position == 'left' and cell.caption
                  image_x = (bounds.width / 2) + options[:image_text_spacing]
                  caption_y = cell_inner_height + options[:cell_padding]
                end

                # If the caption is going on the right, move the caption to the right
                if board.captions_position == 'right' and cell.caption
                  caption_x = bounds.width / 2
                  image_x = options[:cell_padding]
                  caption_y = cell_inner_height + options[:cell_padding]
                end

                # If there's no image in this cell, center the text in the entire cell
                if !cell.image_url and cell.caption
                  caption_x = options[:cell_padding]
                  caption_y = bounds.height - options[:cell_padding]
                  caption_width = cell_inner_width
                  caption_height = cell_inner_height
                end

                if options[:debug]
                  p "caption            #{cell.caption}"
                  p "image_y            #{image_y}"
                  p "image_height       #{image_height}"
                  p "cell_inner_height  #{cell_inner_height}"
                  p "-----------"
                end

                # Sanity checking time.
                # If any image has been assigned a height < 0, raise an exception.
                if image_height < 0
                  raise PdfGenerationException.new(
                    message: "Not enough height in cell for image",
                    category: 'insufficient_cell_height',
                    overflow: image_height.round.abs
                  )
                end

                # Layout Calculations are all done now. Time to the cell and caption!

                # FOR DEBUG: Draws axes around the cell.
                if options[:debug]
                  # stroke_axis step_length: 10

                  # Draws a rectangle around the caption and image. Useful for layout!
                  stroke do
                    stroke_color 'df0612'
                    rectangle [caption_x, caption_y], caption_width, caption_height
                    rectangle [image_x, image_y], image_width, image_height
                  end
                end

                # Draw Cell background colour
                if cell.pdf_colours.background
                  fill_color cell.pdf_colours.background
                  fill {
                    rectangle [bounds.left, bounds.top], bounds.width, bounds.height
                  }
                  fill_color options[:default_background_colour]
                end

                # Draw Cell borders
                if options[:draw_cell_borders]
                  stroke_color cell.pdf_colours.border || options[:default_border_colour]
                  self.line_width = options[:cell_border_width]
                  stroke_bounds
                  stroke_color options[:default_border_colour]
                end

                # Draw the captions
                if cell.caption and board.captions_position != 'hidden'

                  fill_color cell.pdf_colours.text || options[:default_text_colour]

                  text_box cell.caption, at: [caption_x, caption_y],
                               width: caption_width,
                               height: caption_height,
                               size: options[:font_size],
                               align: :center,
                               valign: :center,
                               overflow: options[:caption_overflow]
                               # single_line: true
                end

                # If there's an image, draw it
                if cell.image_url && !options[:skip_images]

                  begin

                    bounding_box([image_x, image_y], width: image_width, height: image_height) do |box|

                      # Move the cursor, so we can draw the image or a failure message.
                      move_cursor_to image_y

                      Rails.logger.debug("Loading cell image for board #{board.id}, cell #{cell.id}: #{cell.image_url}")
                      cell_image_start = Time.now
                      image = Faraday.get(URI.encode(cell.image_url)) do |req|
                        req.options.timeout = 10        # 10 second timeout for cell images
                        req.options.open_timeout = 3    # 3 second connection timeout
                      end
                      cell_image_load_time = Time.now - cell_image_start
                      image_load_count += 1
                      Rails.logger.debug("Cell image loaded in #{cell_image_load_time.round(2)}s for board #{board.id}, cell #{cell.id}")

                      image_type = image.headers['content-type']


                      # The people who wrote prawn-svg also neglected to include a 'fit' attribute,
                      # so we have to do it manually here
                      if image_type.in? allowed_svg_mime_types
                        
                        # If the Cell has a Picto that is adaptable
                        # and the Cell has custom hair/skin colours set, adapt the SVG.
                        if cell.picto and cell.picto.images.last.adaptable and (cell.has_adaptations?)
                          svg_body = StyleAdaptableSymbolJob.perform_now(svg_body: image.body, adaptations: {
                            hair: cell.hair_colour,
                            skin: cell.skin_colour
                          })
                        else
                          svg_body = image.body
                        end
                        
                        # Clean/optimise the SVG before embedding it.
                        # This also fixes an issue that can prevent embedded data-uri images from being rendered
                        # in the PDF.
                        clean_svg = SvgOptimizer.optimize(svg_body, SVG_CLEANER_PLUGINS)

                        # Debug option to write out the cleaned SVG
                        # File.write(Rails.root.join('tmp/cleaned.svg'), clean_svg)

                        # Load the SVG and find its dimensions.
                        svg_obj = ::Prawn::Svg::Interface.new clean_svg, self, {
                          position: :center,
                          vposition: :center,
                          enable_web_requests: true,
                          fallback_font_name: 'Arial'
                        }

                        # Calculate a size for the SVG that will fit the required cell area.
                        fit = BoardBuilder::BoardToPdf::fit_image_to_dimensions({
                                                                                  height: svg_obj.document.sizing.output_height,
                                                                                  width: svg_obj.document.sizing.output_width,
                                                                                  fit: [image_width, image_height]
                                                                                })

                        # Resize the SVG to those dimensions.
                        svg_obj.resize(width: fit[0], height: fit[1])

                        # Draw the SVG.
                        svg_obj.draw

                      elsif image_type.in? allowed_raster_mime_types
                        # Images supplied to Prawn must respond to 'read' and 'rewind'
                        # so we use StringIO.
                        image StringIO.new(image.body),
                              position: :center,
                              vposition: :center,
                              # vposition: image_y - caption_height + options[:cell_padding],
                              fit: [image_width, image_height]
                      end

                    end


                  rescue Faraday::Error => e
                    image_error_count += 1
                    Rails.logger.warn("Failed to load image for board #{board.id}, cell #{cell.id}: #{e.message}")
                    text 'Failed to load this image', align: :center
                  end

                end
              end
            end
          end

        end
        
        # grid.show_all


      end

      # pp prawn_doc.warnings

      end_time = Time.now
      duration = (end_time - start_time).round(2)
      Rails.logger.info("Completed PDF generation for board #{board.id} in #{duration} seconds - loaded #{image_load_count} images, #{image_error_count} failed")

      prawn_doc
    end

    # Copied and adapted from Prawn's own calc_image_dimensions
    def self.fit_image_to_dimensions(options)
      w = options[:width]
      h = options[:height]

      bw, bh = options[:fit]
      bp = bw / bh.to_f
      ip = w / h.to_f
      if ip > bp
        w = bw
        h = bw / ip
      else
        h = bh
        w = bh * ip
      end

      [w, h]
    end
  end
end