require 'rails_helper'

RSpec.describe "Errors", type: :request do
  describe '404 Errors' do
    it 'should return 404 on nonexistent routes' do
      get '/sflksdfsf'
      expect(response).to have_http_status :not_found
      expect(response).to render_template 'errors/not_found'
    end
    
    it 'should return 404 on ActiveRecord::RecordNotFound' do
      get '/symbolsets/sflksdfsf'
      expect(response).to have_http_status :not_found
      expect(response).to render_template 'errors/not_found'
    end
  end
  
  describe '401 errors' do
    it 'should return 401' do
      @symbolset = FactoryBot.create :symbolset
      get symbolset_path @symbolset
      expect(response).to have_http_status :unauthorized
      expect(response).to render_template 'errors/unauthorised'
    end
  end
end
