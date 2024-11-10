require 'rails_helper'

RSpec.describe SymbolsetsController, type: :controller do
  before :each do
    @unauthorised_user = FactoryBot.create(:user)
  end
  
  describe 'GET #index' do
    it 'assigns only published @symbolsets' do
      draft_symbolset = FactoryBot.create(:symbolset)
      expect(draft_symbolset.status).to eq('draft')
      published_symbolset = FactoryBot.create(:symbolset, :published)
      get :index
      expect(assigns(:symbolsets)).to eq([published_symbolset])
    end
    
    it 'orders Symbolsets by name' do
      last_symbolset = FactoryBot.create :symbolset, :published, name: 'Z Symbolset'
      first_symbolset = FactoryBot.create :symbolset, :published, name: 'A Symbolset'
      get :index
      expect(assigns(:symbolsets)).to eq [first_symbolset, last_symbolset]
    end
    
    it 'renders the index template' do
      get :index
      expect(response).to render_template("index")
    end

    it 'has a 200 status code' do
      get :index
      expect(response.status).to eq(200)
    end
  end
  
  describe 'GET #show' do
    it 'assigns the requested symbolset to @symbolset' do
      symbolset = FactoryBot.create(:symbolset, :published)
      
      get :show, params: {id:symbolset}
      expect(assigns(:symbolset)).to eq(symbolset)
      expect(response).to be_successful
    end

    it "renders the #show view" do
      get :show, params: {id: FactoryBot.create(:symbolset, :published)}
      expect(response).to render_template :show
    end

    it 'shows Symbols only from the specified symbol set' do
      symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 1)
      symbolset2 = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 1)

      get :show, params: {id:symbolset}

      expect(assigns(:labels).length).to eq 1
      expect(assigns(:labels)).to contain_exactly symbolset.labels.first
    end
    
    it 'shows all Symbols in the Symbol Set in the current locale/Language' do
      # Create a Symbolset with two Pictos, each with one English label
      symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 2)
      expect(symbolset.pictos.first.labels.count).to eq 1
      expect(symbolset.pictos.first.labels.first.language).to eq Language.find_by(iso639_1: :en)
      
      # Change the second picto's label to French
      symbolset.pictos.second.labels.first.update(language: Language.find_by(iso639_1: :fr))
      expect(symbolset.pictos.second.labels.count).to eq 1
      expect(symbolset.pictos.second.labels.first.language).to eq Language.find_by(iso639_1: :fr)
      
      # Check the symbolset has two pictos
      expect(symbolset.pictos.count).to eq 2
      
      get :show, params: {id:symbolset}
      
      # We should get back one label
      expect(assigns(:labels).length).to eq 1
      expect(assigns(:labels)).to contain_exactly symbolset.pictos.first.labels.first
      expect(response).to be_successful
    end

    it 'returns 404 for non-existent Symbolsets' do
      get :show, params: {id: 99999999}
      expect(response).to have_http_status 404
      expect(response).to render_template('errors/not_found')
    end

    describe 'Archived symbols' do
      before :each do
        @symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 2)
        @archived_picto = @symbolset.pictos.first
        @archived_picto.update!(archived: true)
        @unarchived_picto = @symbolset.pictos.second
      end

      context "for unauthenticated users" do
        it 'does not show archived symbols' do
          get :show, params: {id: @symbolset}
          expect(assigns(:labels).length).to eq 1
          expect(assigns(:labels)).to contain_exactly @unarchived_picto.labels.first
        end
      end

      context "for users authorised on the symbolset" do
        it 'does not show archived symbols' do
          sign_in @symbolset.users.first
          get :show, params: {id: @symbolset}
          expect(assigns(:labels).length).to eq 1
          expect(assigns(:labels)).to contain_exactly @unarchived_picto.labels.first
        end
      end
    end
    
    describe 'Symbol visibility' do
      before :each do
        @symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 2)
        @symbolset.pictos.first.update(visibility: 'collaborators')
  
        # Check the symbolset has two pictos
        expect(@symbolset.pictos.count).to eq 2
        expect(@symbolset.pictos.first.visibility).to eq 'collaborators'
        expect(@symbolset.pictos.second.visibility).to eq 'everybody'
      end
      context "for unauthenticated users" do
        it 'shows only public Symbols' do
          get :show, params: {id:@symbolset}
          expect(assigns(:labels).length).to eq 1
          expect(assigns(:labels)).to contain_exactly @symbolset.pictos.second.labels.first
          expect(response).to be_successful
        end
      end
  
      context "for users authorised on the symbolset" do
        it 'shows all Symbols' do
          sign_in @symbolset.users.first
          get :show, params: {id:@symbolset}
          expect(assigns(:labels).length).to eq 2
          expect(assigns(:labels)).to contain_exactly @symbolset.pictos.first.labels.first, @symbolset.pictos.second.labels.first
          expect(response).to be_successful
        end
      end
    end
  end

  describe "GET #new" do
    context "for authenticated users" do
      it "renders the new template" do
        sign_in FactoryBot.create(:user)
        get :new
        expect(response).to render_template('new')
      end
    end
  
    context "for unauthenticated users" do
      it "redirects to sign in" do
        get :new
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
  
  describe "POST #create" do
    context "for authenticated users" do
      it "creates a new symbolset" do
        sign_in FactoryBot.create(:user)
        params = FactoryBot.build(:symbolset)
        params.slug = nil # Override the built "" slug value
        expect{post :create, params: { symbolset: params.attributes }, format: :js}.to change(Symbolset,:count).by(1)
      end

      it "redirects to the new symbolset" do
        sign_in FactoryBot.create(:user)
        post :create, params: { symbolset: FactoryBot.build(:symbolset).attributes }, format: :js
        expect(response).to redirect_to symbolset_path(assigns(:symbolset))
      end
    end
  
    context "for unauthenticated users" do
      it "redirects to sign in" do
        post :create, params: { symbolset: FactoryBot.build(:symbolset).attributes }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
  
  describe "GET #edit" do
    before :each do
      @symbolset = FactoryBot.create(:symbolset)
    end

    context "for users authorised on the symbolset" do
      it "renders the edit form" do
        sign_in @symbolset.users.first
        get :edit, params: {id: @symbolset }
        expect(response).to render_template('edit')
      end
    end

    context "for users not authorised on the symbolset" do
      it "redirects unauthenticated visitors to sign in" do
        get :edit, params: {id: @symbolset.id }
        expect(response).to redirect_to(new_user_session_path)
      end
  
      it "denies the action to non-members of the symbolset" do
        sign_in @unauthorised_user
        get :edit, params: {id: @symbolset }
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe "PUT #update" do
    before :each do
      @symbolset = FactoryBot.create(:symbolset, name: 'ABC Symbols')
    end

    context "for users authorised on the symbolset" do
      context "with valid attributes" do
        it "assigns the requested Symbolset" do
          sign_in @symbolset.users.first
          put :update, params: {id: @symbolset,symbolset: FactoryBot.attributes_for(:symbolset)}
          expect(assigns(:symbolset)).to eq(@symbolset)
        end
    
        it "updates the Symbolset with the specified attributes" do
          sign_in @symbolset.users.first
          @symbolset.name = 'XYZ Symbols'
          put :update, params: {id: @symbolset, symbolset: @symbolset.attributes}
          @symbolset.reload
          expect(@symbolset.name).to eq('XYZ Symbols')
        end
    
        it "redirects to the updated Symbolset" do
          sign_in @symbolset.users.first
          put :update, params: {id: @symbolset, symbolset: @symbolset.attributes}
          expect(response).to redirect_to symbolset_path(@symbolset)
        end
      end
  
      context "with invalid attributes" do
        it "renders an updated form in javascript" do
          sign_in @symbolset.users.first
          @symbolset.name = nil
          expect(@symbolset.valid?).to be false
          expect{
            put :update, params: {id: @symbolset, symbolset: @symbolset.attributes}, format: :js
          }.to_not change{@symbolset.name}
          expect(response.content_type).to eq 'text/javascript; charset=utf-8'
        end
      end
    end

    context "for users not authorised on the symbolset" do
      it "redirects unauthenticated visitors to sign in" do
        put :update, params: {id: @symbolset, symbolset: FactoryBot.attributes_for(:symbolset)}
        expect(response).to redirect_to(new_user_session_path)
      end
  
      it "denies the action to non-members of the symbolset" do
        sign_in @unauthorised_user
        put :update, params: {id: @symbolset, symbolset: FactoryBot.attributes_for(:symbolset)}
        expect(response).to have_http_status :unauthorized
      end
    end
  end
  
  describe "POST #import" do
    context "with a valid CSV file" do
      it "imports the file" do
        symbolset = FactoryBot.create(:symbolset)
        sign_in symbolset.users.first
        expect{post :upload, params: {id: symbolset, csv_file: fixture_file_upload('../symbolset.valid.csv', 'text/csv')}}.to_not raise_exception
      end
    end
    context "with an invalid CSV file" do
      it "does not import the file" do
        symbolset = FactoryBot.create(:symbolset)
        sign_in symbolset.users.first
        expect{post :upload, params: {id: symbolset, csv_file: fixture_file_upload('../symbolset.invalid.missing_data.csv', 'text/csv')}}.to raise_exception CsvMissingRequiredValuesException
      end
    end
  end

  describe "GET #archive" do
    before :each do
      @symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 2)
      @archived_picto = @symbolset.pictos.first
      @archived_picto.update!(archived: true)
    end

    context "for users authorised on the symbolset" do
      it 'shows all Symbols' do
        sign_in @symbolset.users.first
        get :archive, params: {id:@symbolset}
        expect(response).to have_http_status :success

        expect(assigns(:pictos).length).to eq 1
        expect(assigns(:pictos)).to contain_exactly @archived_picto
        expect(response).to be_successful
      end
    end

    context "for users not authorised on the symbolset" do
      it "redirects unauthenticated visitors to sign in" do
        get :archive, params: {id: @symbolset}
        expect(response).to redirect_to(new_user_session_path)
      end

      it "denies the action to non-members of the symbolset" do
        sign_in @unauthorised_user
        get :archive, params: {id: @symbolset}
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  # There is no destroy method on Symbolset, and this may not be implemented.
  # If it is, then here are the tests.
  # describe "DELETE #delete" do
  #   before :each do
  #     @symbolset = FactoryBot.create(:symbolset, :with_user)
  #   end
  #
  #   context "for users authorised on the Symbolset" do
  #     it "deletes the Symbolset" do
  #       sign_in @symbolset.users.first
  #       expect{
  #         delete :destroy, params: {id: @symbolset.id}
  #       }.to change(Symbolset,:count).by(-1)
  #     end
  #
  #     it "redirects to the homepage" do
  #       sign_in @symbolset.users.first
  #       delete :destroy, params: {id: @symbolset.id}
  #       expect(response).to redirect_to root_path
  #     end
  #   end
  #
  #   context "for users not authorised on the Symbolset" do
  #     it "redirects unauthenticated visitors to sign in" do
  #       delete :destroy, params: {id: @symbolset.id}
  #       expect(response).to redirect_to(new_user_session_path)
  #     end
  #
  #     it "denies the action to non-members of the Symbolset" do
  #       sign_in @unauthorised_user
  #       delete :destroy, params: {id: @symbolset.id}
  #       expect(response).to have_http_status :unauthorized
  #     end
  #   end
  # end
end