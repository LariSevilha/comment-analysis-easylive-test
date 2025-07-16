class Api::V1::CommentsController < ApplicationController
  def index
    user = User.find_by(id: params[:user_id])
    if user.nil?
      render json: { error: 'User not found' }, status: :not_found
      return
    end

    comments = user.comments.includes(:post).order(created_at: :desc)

    render json: {
      comments: comments.map do |comment|
        build_comment_response(comment)
      end
    }
  end

  def show
    comment = Comment.includes(:user, :post).find_by(id: params[:id])
    if comment.nil?
      render json: { error: 'Comment not found' }, status: :not_found
      return
    end

    render json: { comment: build_comment_response(comment) }
  end

  def reprocess
    comment = Comment.includes(:user).find_by(id: params[:id])
    if comment.nil?
      render json: { error: 'Comment not found' }, status: :not_found
      return
    end

    if comment.user.nil? || comment.post.nil?
      render json: { error: 'Comment associations missing (user or post)' }, status: :unprocessable_entity
      return
    end

    comment.update!(
      status: :pending,
      keyword_matches_count: 0,
      translated_body: nil,
      processed: nil
    )

    comment.process_comment!

    RecalculateUserMetricsService.new(comment.user).call

    render json: {
      message: 'Comment reprocessed successfully',
      comment: {
        id: comment.id,
        status: comment.status,
        keyword_matches_count: comment.keyword_matches_count,
        translated_body: comment.translated_body,
        processed_at: comment.processed
      }
    }
  rescue StandardError => e
    Rails.logger.error "Failed to reprocess comment #{params[:id]}: #{e.message}"
    render json: { error: 'Failed to reprocess comment', details: e.message }, status: :internal_server_error
  end

  private

  def build_comment_response(comment)
    {
      id: comment.id,
      external_id: comment.external_id,
      body: comment.body,
      translated_body: comment.translated_body,
      name: comment.name,
      email: comment.email,
      status: comment.status,
      keyword_matches_count: comment.keyword_matches_count,
      processed_at: comment.processed,
      user: {
        id: comment.user.id,
        username: comment.user.username,
        name: comment.user.name
      },
      post: {
        id: comment.post.id,
        title: comment.post.title,
        external_id: comment.post.external_id
      },
      created_at: comment.created_at,
      updated_at: comment.updated_at
    }
  end
end
