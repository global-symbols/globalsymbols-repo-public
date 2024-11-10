class StyleAdaptableSymbolJob < ApplicationJob
  queue_as :default

  def perform(svg_body:, adaptations:)
  
    svg = Nokogiri::XML(svg_body)
    
    adaptations.each do |key, value|
      # Set the fill attribute of all elements with this class.
      # prawn-pdf doesn't support overriding attributes with !important in CSS,
      # so it's easier to just replace the fill attribute.
      svg.css(".aac-#{key}-fill").each { |node|
        # Apply the fill value to the current node and all descendents
        node.traverse { |descendent_node| descendent_node['fill'] = value }
      }
    end
    
    svg.to_xml
  end
end
