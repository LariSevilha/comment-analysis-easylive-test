class Api::V1::UsersController < ApplicationController
  def index
    users = User.analyzed.includes(:posts, :comments)
    
    render json: {
      users: users.map do |user|
        {
          id: user.id,
          username: user.username,
          name: user.name,
          email: user.email,
          posts_count: user.posts.count,
          comments_count: user.comments.count,
          approved_comments_count: user.approved_comments_count,
          rejected_comments_count: user.rejected_comments_count,
          approval_rate: user.approval_rate,
          processed_at: user.processed,
          analysis_metrics: user.analysis_metrics
        }
      end
    }
  end

  def show
    user = User.find(params[:id])
    
    render json: {
      user: {
        id: user.id,
        username: user.username,
        name: user.name,
        email: user.email,
        external_id: user.external_id,
        address: user.address,
        phone: user.phone,
        website: user.website,
        company: user.company,
        posts_count: user.posts.count,
        comments_count: user.comments.count,
        approved_comments_count: user.approved_comments_count,
        rejected_comments_count: user.rejected_comments_count,
        approval_rate: user.approval_rate,
        processed_at: user.processed,
        analysis_metrics: user.analysis_metrics,
        created_at: user.created_at,
        updated_at: user.updated_at
      },
      posts: user.posts.map do |post|
        {
          id: post.id,
          title: post.title,
          body: post.body,
          external_id: post.external_id,
          comments_count: post.comments.count,
          created_at: post.created_at
        }
      end
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end
end