require 'sidekiq/web'

Lagotto::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => "users/omniauth_callbacks" }

  devise_scope :user do
    get 'sign_in', :to => 'devise/sessions#new', :as => :new_session
    post 'sign_in', :to => 'devise/session#create', :as => :session
    delete 'sign_out', :to => 'devise/sessions#destroy', :as => :destroy_user_session
  end

  authenticate :user, lambda { |u| u.is_admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  #root :to => "ember#index"
  #get '/docs/*path' => 'ember#index'

  # simplify GET route to works
  #get '/:id', to: 'works#show', constraints: { id: /(http|https):\/\/.+/, format: /html/ }
  root :to => "docs#index"

  resources :agents do
    resources :publisher_options, only: [:show, :edit, :update]
  end
  resources :api_requests
  resources :contributors, constraints: { :id => /.+/ }
  resources :docs, :only => [:index, :show], :constraints => { :id => /[0-z\-\.\(\)]+/ }
  resources :filters
  resources :notifications
  resources :publishers, constraints: { :id => /.+/ }
  resources :relations

  # use namespace for rss feeds rather than file extension
  namespace :rss, defaults: { format: "rss" } do
    resources :works, constraints: { :id => /.+/ }, only: [:show]
    resources :sources, only: [:show]
  end

  # redirect old rss routes
  get '/sources/:id.rss', to: redirect { |params, request| "/rss/sources/#{request.params[:id]}?#{request.params.to_query}" }

  resources :sources
  resources :status, :only => [:index]
  resources :users

  # constraints is added to allow dot in the url (doi is used to show article)
  resources :works, constraints: { :id => /.+/, :format => /html|js/ }

  get "oembed", to: "oembed#show"

  get "/files/alm_report.zip", to: redirect("/files/alm_report.zip")
  get "/api", to: "api/index#index"

  namespace :api, defaults: { format: "json" } do
    scope module: :v6, constraints: ApiConstraint.new(version: 6, default: :true) do
      match 'relations', to: 'relations#index', via: [:get, :post]

      concern :workable do
        resources :works, constraints: { :id => /.+?/, format: false }
      end

      concern :eventable do
        resources :aggregations, path: "events"
      end

      resources :agents
      resources :aggregations, path: "events"
      resources :api_requests, only: [:index]
      resources :contributor_roles, only: [:index, :show]
      resources :contributions
      resources :contributors, constraints: { :id => /.+/ } do
        resources :contributions
      end
      resources :deposits
      resources :docs, only: [:index, :show]
      resources :groups, only: [:index, :show]
      resources :notifications
      resources :publishers, constraints: { :id => /.+/ }, concerns: [:workable, :eventable]
      resources :relation_types, only: [:index, :show]
      resources :sources, concerns: [:workable, :eventable] do
        resources :months
      end
      resources :status, only: [:index]
      resources :work_types, only: [:index, :show]
      resources :works, constraints: { :id => /.+?/, :format=> false } do
        resources :relations
        resources :versions
        resources :recommendations
        resources :aggregations, path: "events"
      end
    end
  end

  # rescue routing errors
  match "*path", to: "notifications#routing_error", via: [:get, :post]
end
