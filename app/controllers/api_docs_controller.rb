# frozen_string_literal: true

class APIDocsController < ApplicationController
  skip_before_action :authenticate_user!
  layout false

  def show
  end
end

