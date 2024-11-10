require 'rails_helper'

RSpec.describe ConceptsController, type: :controller do

  describe "GET #show" do
    it "assigns the correct concept" do
      concept = FactoryBot.create(:concept)
      get :show, params: {id: concept.id}
      expect(assigns(:concept)).to eq(concept)
    end
  
    it "renders the show template" do
      concept = FactoryBot.create(:concept)
      get :show, params: {id: concept.id}
      expect(response).to render_template('show')
    end
  end

end
