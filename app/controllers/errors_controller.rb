class ErrorsController < ApplicationController
  
  # Anyone can view Errors (so kind!)
  skip_before_action :authenticate_user!
  
  def unauthorised
    render status: :unauthorized
  end
  
  def not_found
    render status: :not_found
  end
end
