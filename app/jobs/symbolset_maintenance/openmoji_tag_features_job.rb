class SymbolsetMaintenance::OpenmojiTagFeaturesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    symbolset = Symbolset.find_by!(slug: :openmoji)

    symbolset.pictos.each do |picto|

      p "#{picto.id} - #{picto.labels.first.text}"

      image = picto.images.last

      # For now, we assume the image is not adaptable.
      # This process checks whether adaptations exist, and sets Image.adaptable accordingly.
      image.adaptable = false
      # image = Symbolset.find_by(slug: :openmoji).pictos.first.images.first

      svg = Nokogiri::XML(image.imagefile.read)

      # If hair/skin is present, tag the element and set the image as adaptable
      # Openmoji group feature elements (e.g. <g id="hair">...</g>), and these groups appear even when they're empty.
      # So, we have to check whether there are any elements inside the feature groups before tagging.

      features = ['hair', 'skin']

      features.each do |feature|
        # Use a CSS search to find SVG elements tagged #hair or #skin
        svg.css("##{feature}").each { |node|

          aac_class_name = "aac-#{feature}-fill"

          # If the node has no children OR this is a pre-adapted symbol, remove the class (if present) and continue to the next node.
          if node.children.count == 0 or picto.labels.first.text.downcase.include?('skin tone')
            node.remove_class(aac_class_name)
            p "Removing #{feature} adaptations: #{node.children.count} g##{feature} children or symbol label contains 'skin tone'"
            next
          end

          p "Adding #{feature} adaptations"

          # Add the class on the <g> group if it's not already set.
          node.add_class(aac_class_name)

          # Set the image as adaptable
          image.adaptable = true
        }
      end

      # If the image has changed (i.e. been set as adaptable), load in the tagged SVG and save it.
      if image.changed?

        p 'image changed!'

        # Prepare a StringIO of the SVG file body, to avoid extracting the file to disk.
        # This will be used by the Carrierwave uploader.
        svg_stringio = StringIO.new(svg.to_xml)
        # We have to fool Carrierwave by providing a filename in the StringIO.
        def svg_stringio.original_filename; 'temp.svg'; end

        image.imagefile = svg_stringio
        begin
          image.save!
          p 'Saved'
        rescue ActiveRecord::RecordInvalid => e
          pp 'COULD NOT SAVE!'
          p e
        end

      end

      # Inject hair and skin tones
      # svg_body.gsub!('id="hair"', 'id="hair" class="aac-hair-fill"')
      # svg_body.gsub!('id="skin"', 'id="skin" class="aac-skin-fill"')

    end
  end
end
