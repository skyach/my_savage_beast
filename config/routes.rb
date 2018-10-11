# Rails.application.routes.draw do
SavageBeast::Engine.routes.draw do
  resources :forums do
    resources :topics do
      resources :posts
      resource :monitorship, :controller => :monitorships
    end
  end

  resources :posts do
    collection do
      get :index, :as => "all"
      get :search, :as => "search_all"
    end
  end

  %w(forum).each do |attr|
    resources :posts, :as => "#{attr}_posts", :path_prefix => "/#{attr.pluralize}/:#{attr}_id"
  end

  # resources :forums, only: [] do
  #   resources :posts
  # end
  #
  # resources :forums
  # scope 'forums/:forum_id/' do
  #   resources :topics
  # end
  # scope 'forums/:forum_id/topics/:topic_id' do
  #   resources :posts
  # end
  # scope 'forums/:forum_id/topics/:topic_id' do
  #   resource :monitorship, :controller => :monitorships
  # end

  resources :topics
  resources :monitorship
end
