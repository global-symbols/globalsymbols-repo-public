module KnowledgeBaseHelper
  def redcarpet(renderer = Redcarpet::Render::HTML)
    Redcarpet::Markdown.new(renderer, filter_html: true, tables: true)
  end
end
