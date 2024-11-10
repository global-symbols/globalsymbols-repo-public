module PagesHelper
  
  # Used by the search form to flip the scope param between 'all' and 'symbolset'
  def search_path_with_scope(scope)
    url_for(params.permit!.merge({scope: scope}))
  end
end
