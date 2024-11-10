class PdfGenerationException < Exception
  attr_reader :category
  attr_reader :overflow

  def initialize(message: "", category: nil, overflow: nil)
    @category = category
    @overflow = overflow
    super(message)
  end

  def attributes
    {
      message: self.message,
      category: self.category,
      overflow: self.overflow
    }
  end
end