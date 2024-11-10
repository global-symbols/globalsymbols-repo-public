class KnowledgeBaseArticleRenderer < Redcarpet::Render::HTML
  # For available methods, see
  # https://github.com/vmg/redcarpet#and-you-can-even-cook-your-own

  # Add .img-fluid to images, so they fit within the content box.
  def image(link, title, alt_text)
    "<img src='#{link}' alt='#{alt_text}' title='#{title}' class='img-fluid'>"
  end

  def table(header, body)
    "<table class='table table-hover'>
      <thead class='bg-light'>#{header}</thead>
      <tbody>#{body}</tbody>
    </table>"
  end

  # Headers are demoted by one level, so <h1> is 'Knowledge Base', <h2> is Article Title
  # and in-article headings are <h3> and below.
  # This allows heading levels in Contentful to be detached from the layout of the website.
  def header(text, header_level)
    "<h#{header_level + 1}>#{text}</h#{header_level + 1}>"
  end

end