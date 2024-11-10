Rails.application.routes.draw do
  use_doorkeeper_openid_connect
  use_doorkeeper

  devise_scope :user do
    get 'users/change_password' => 'users/registrations#change_password'
    put 'users/change_password' => 'users/registrations#update_password'

    get 'users/saved' => 'users/registrations#saved'
  end
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions'
  }

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root controller: :pages, action: :home

  get :search, controller: :pages, action: :search
  get :contact, controller: :pages, action: :contact

  mount GrapeSwaggerRails::Engine => '/api/docs'
  mount API, at: '/api'

  resources :concepts, only: [:index, :show]

  resources :surveys, only: [:show] do
    resources :questions, only: [:show, :update], controller: :survey_questions do

    end
    member do
      get :print
      post :create_response
      get :thank_you
    end
  end

  resources :news, controller: :articles, only: [:index, :show] do
    collection do
      get 'page/:page', controller: :articles, action: :index, as: :page # Paginates Articles
      get 'preview/:id', controller: :articles, action: :preview, as: :preview # Previewer for Articles
    end
  end

  resources :symbolsets do
    member do
      get :archive
      get :review
      get :import
      post :import, to: 'symbolsets#upload'
      get :download
      get :translate
    end

    resources :symbols, controller: :pictos do
      member do
        post :comment
      end
      resources :concepts, only: [:index, :create, :destroy], controller: :picto_concepts
      resources :labels, only: [:index, :create, :destroy, :edit, :update], controller: :picto_labels do
        member do
          patch :publish_translation
        end
      end
    end
    resources :collaborators, only: [:index, :create, :destroy]

    resources :surveys, controller: :survey_editor do
      member do
        post :add_symbol
        post :remove_symbol
        get :export
      end

      resources :responses, only: [:index, :show, :new, :create], controller: :survey_response_analysis
      resources :symbols, only: [:index], controller: :survey_picto_analysis
    end
  end

  resources :translation, only: [:create, :update] do
    post :suggest
    post :suggest_all
    post :accept_all
  end

  get '/help', to: 'pages#help_article'

  get 'about/featured-board-sets', controller: :pages, action: :featured_board_sets
  # Contentful-based about/*something* pages.
  get 'about/:id', controller: :pages, action: :contentful_page, as: :about_page
  get :about, controller: :pages, action: :contentful_page, id: :about

  # get 'kb/:id', controller: :pages, action: :contentful_kb_article
  resources :knowledge_base, path: 'knowledge-base', only: [:index, :show] do
    collection do
      get :search
    end
  end

  get 'uploads/:environment/image/imagefile/:id/:hash', controller: :images, action: :show

  get '*path', controller: :errors, action: :not_found, via: :all, constraints: lambda { |request| !request.path_parameters[:path].start_with?('rails/') }
end
