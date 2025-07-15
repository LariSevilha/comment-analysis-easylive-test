Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Main endpoint for user analysis
      post 'users/:username/analyze', to: 'users#analyze' # Alterado para suportar username
      get 'users/:username', to: 'users#show'

      # Keywords management
      resources :keywords, only: [:index, :create, :update, :destroy]

      # Progress tracking
      resources :progress, only: [:show, :index]

      # Comments
      get 'users/:username/comments', to: 'comments#index'

      # Metrics
      get 'metrics/group', to: 'metrics#group'
      post 'metrics/recalculate', to: 'metrics#recalculate'
    end
  end

  get 'health', to: proc { [200, {}, ['OK']] }
end