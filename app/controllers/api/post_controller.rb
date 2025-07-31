# app/controllers/api/posts_controller.rb
module Api
    class PostsController < ApplicationController
      def create
        post = Post.new(post_params)
  
        if post.save
          render json: { post: post }, status: :created
        else
          render json: { errors: post.errors.full_messages }, status: :unprocessable_entity
        end
      end
  
      private
  
      def post_params
        params.require(:post).permit(:title, :body, :user_id, :external_id)
      end
    end
  end
  