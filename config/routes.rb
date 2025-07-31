Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do 
    resources :posts, only: [:create]
    
    resources :comments, only: [:create, :index] do
      collection do
        post :analyze
        post :translate
        post :reprocess
        get 'progress/:job_id', to: 'comments#progress'
        get 'metrics/:username', to: 'comments#metrics'
      end
      
      member do
        get :translation_status  
      end
    end
    
    resources :keywords, only: [:index, :show, :create, :update, :destroy]

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
end