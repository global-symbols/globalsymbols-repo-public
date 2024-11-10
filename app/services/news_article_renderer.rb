class NewsArticleRenderer < Redcarpet::Render::HTML
  # For available methods, see
  # https://github.com/vmg/redcarpet#and-you-can-even-cook-your-own
  
  # Add .img-fluid to images, so they fit within the content box.
  def image(link, title, alt_text)
    "<img src='#{link}' alt='#{alt_text}' title='#{title}' class='img-fluid'>"
  end

end