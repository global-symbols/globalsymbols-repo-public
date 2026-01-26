class ComingSoonController < ApplicationController
  # Anyone can view the "coming soon" pages
  skip_before_action :authenticate_user!

  def knowledge_base
    render status: :ok
  end
end

