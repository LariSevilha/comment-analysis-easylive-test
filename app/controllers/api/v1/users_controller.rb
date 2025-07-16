class Api::V1::UsersController < Api::V1::BaseController
  def index
    users = User.processed.includes(:user_metrics).order(:username)
    
    render_success({
      users: users.map do |user|
        {
          username: user.username,
          name: user.name,
          email: user.email,
          processed: user.processed,
          comments_count: user.total_comments_count,
          approved_count: user.approved_comments_count,
          rejected_count: user.rejected_comments_count
        }
      end,
      total_count: users.count
    })
  end
  
  def show
    user = User.find_by!(username: params[:id])
    
    render_success({
      username: user.username,
      name: user.name,
      email: user.email,
      processed: user.processed,
      comments: user.comments.includes(:post).map do |comment|
        {
          id: comment.id,
          body: comment.body,
          translated_body: comment.translated_body,
          status: comment.status,
          keyword_matches_count: comment.keyword_matches_count,
          processed: comment.processed,
          post_title: comment.post.title
        }
      end,
      metrics: user.user_metrics.each_with_object({}) do |metric, hash|
        hash[metric.metric_type] = metric.value
      end
    })
  end
end
