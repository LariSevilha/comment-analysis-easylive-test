Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    post 'comments/analyze', to: 'comments#analyze'
    get 'comments/progress/:job_id', to: 'comments#progress'
    get 'comments/metrics/:username', to: 'comments#metrics'

    resources :keywords, only: [:index, :show, :create, :update, :destroy]

    # Cache management routes
    get 'cache/health', to: 'cache#health'
    get 'cache/stats', to: 'cache#stats'
    get 'cache/config', to: 'cache#configuration'
    post 'cache/warm', to: 'cache#warm'
    post 'cache/benchmark', to: 'cache#benchmark'
    post 'cache/reset_stats', to: 'cache#reset_stats'
    delete 'cache/invalidate', to: 'cache#invalidate'
    get 'cache/circuit_breakers', to: 'cache#circuit_breakers'
    post 'cache/circuit_breakers/:service/reset', to: 'cache#reset_circuit_breaker'
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
