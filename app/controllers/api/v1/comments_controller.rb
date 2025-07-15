class Api::V1::CommentsController < ApplicationController
    def index
      user = User.find_by!(username: params[:username])
      comments = user.comments.includes(:post).order(created_at: :desc)
      
      render json: {
        user: user.username,
        comments: comments.map do |comment|
          {
            id: comment.id,
            post_title: comment.post.title,
            original_body: comment.body,
            translated_body: comment.translated_body,
            status: comment.status,
            matched_keywords: comment.matched_keywords,
            matched_keywords_count: comment.matched_keywords_count,
            created_at: comment.created_at
          }
        end,
        total: comments.count
      }
    end
  end
  