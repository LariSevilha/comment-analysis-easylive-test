Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users, only: [:show], param: :username do
        resources :analyses, only: [:create, :show]
        resources :comments, only: [:index]
      end

      resources :keywords, only: [:index, :create, :update, :destroy]

      resources :metrics, only: [] do
        collection do
          get :group
          post :recalculate
        end
      end

      resources :jobs, only: [:index]
    end
  end

  get 'health', to: proc { [200, {}, ['OK']] }
end