Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :keywords, only: [:index, :create, :update, :destroy]
      resources :users, only: [:index, :show] do
        resources :comments, only: [:index]
      end
      resources :analyses, only: [:create, :show]
      resources :metrics, only: [] do
        collection do
          get :group
          post :recalculate
        end
      end
      resources :jobs, only: [:index]
      resources :comments, only: [:show] do
        post :reprocess, on: :member
      end
    end
  end
end
