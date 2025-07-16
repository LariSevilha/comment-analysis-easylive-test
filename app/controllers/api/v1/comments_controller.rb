class Api::V1::CommentsController < Api::V1::BaseController
    def index
      comments = Comment.includes(:post, :user)
                       .order(created_at: :desc)
                       .limit(params[:limit] || 50)
      
      comments = comments.where(status: params[:status]) if params[:status].present?
      
      render_success({
        comments: comments.map do |comment|
          {
            id: comment.id,
            body: comment.body,
            translated_body: comment.translated_body,
            status: comment.status,
            keyword_matches_count: comment.keyword_matches_count,
            processed: comment.processed,
            user: {
              username: comment.user.username,
              name: comment.user.name
            },
            post: {
              title: comment.post.title
            }
          }
        end,
        total_count: comments.count
      })
    end
    
    def show
      comment = Comment.find(params[:id])
      
      render_success({
        id: comment.id,
        body: comment.body,
        translated_body: comment.translated_body,
        status: comment.status,
        keyword_matches_count: comment.keyword_matches_count,
        processed: comment.processed,
        user: {
          username: comment.user.username,
          name: comment.user.name
        },
        post: {
          title: comment.post.title,
          body: comment.post.body
        }
      })
    end
    
    def reprocess
      comment = Comment.find(params[:id])
      comment.process_classification!
      
      render_success(nil, 'Comment reprocessing initiated')
    end
  end