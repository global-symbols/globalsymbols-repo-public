module ApplicationHelper
  def current_symbolset_id
    begin
      path = Rails.application.routes.recognize_path request.path, method: request.env["REQUEST_METHOD"]
      return path[:id] if path[:controller] == 'symbolsets'
      params[:symbolset_id] || nil
    rescue ActionController::RoutingError
      nil
    end
  end
  
  def current_symbolset
    id = current_symbolset_id
    return nil if id.nil?
    Symbolset.friendly.find_by(id: id) # Using find_by, in case the id doesn't exist
  end
  
  def translation_languages
    # Returns a map of available Languages.
    I18n.available_locales.map { |language| [I18n.t("languages.#{language}", locale: language), language] }.sort
  end

  def text_direction
    I18n.locale.in?([:ar, :ps, :ur]) ? :rtl : :ltr
  end

  def bb_url
    if Rails.env.development?
      "http://#{request.host}:4200"
    else
      "https://app.#{request.host}/en"
    end
  end
end
