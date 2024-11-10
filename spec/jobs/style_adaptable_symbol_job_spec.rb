require 'rails_helper'

RSpec.describe StyleAdaptableSymbolJob, type: :job do
  before :each do
    @svg_body = open(Rails.root.join("spec/fixtures/picto.image.imagefile.adaptable.svg")).read
  end
  
  context 'Given an adaptable SVG and adaptations' do
    before :each do
      @adaptations = {
        hair: '#123456',
        skin: '#ABCDEF',
      }.with_indifferent_access
    end
    it 'Injects the adaptations into the SVG file' do
      output_svg = StyleAdaptableSymbolJob.perform_now(svg_body: @svg_body, adaptations: @adaptations)

      # Check for hair styling (heh)
      expect(output_svg).to include ".aac-hair-fill { fill: #{@adaptations['hair']} !important; }"

      # Check for skin styling
      expect(output_svg).to include ".aac-skin-fill { fill: #{@adaptations['skin']} !important; }"
    end
  end
  
  context 'Given an adaptable SVG and partial adaptations' do
    before :each do
      @adaptations = {
        hair: '#123456',
        skin: nil,
      }.with_indifferent_access
    end
    
    it 'Injects into the SVG file only those adaptations with values' do
      output_svg = StyleAdaptableSymbolJob.perform_now(svg_body: @svg_body, adaptations: @adaptations)
  
      # Check for hair styling (heh)
      expect(output_svg).to include ".aac-hair-fill { fill: #{@adaptations['hair']} !important; }"
  
      # Check for no skin styling
      expect(output_svg).to_not include ".aac-skin-fill"
    end
  end
end
