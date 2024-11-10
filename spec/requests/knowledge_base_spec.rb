require 'rails_helper'

RSpec.describe "KnowledgeBases", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/knowledge_base/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/knowledge_base/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /search" do
    it "returns http success" do
      get "/knowledge_base/search"
      expect(response).to have_http_status(:success)
    end
  end

end
