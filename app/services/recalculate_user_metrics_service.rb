class RecalculateUserMetricsService
    def initialize(user)
      @user = user
    end
  
    def call
      approved = @user.comments.approved.count
      rejected = @user.comments.rejected.count
      total = @user.comments.count
  
      approval_rate = total.positive? ? (approved.to_f / total) * 100 : 0
  
      UserMetric.upsert_all([
        { user_id: @user.id, metric_type: 'total_comments', value: total, created_at: Time.current, updated_at: Time.current },
        { user_id: @user.id, metric_type: 'approved_comments', value: approved, created_at: Time.current, updated_at: Time.current },
        { user_id: @user.id, metric_type: 'rejected_comments', value: rejected, created_at: Time.current, updated_at: Time.current },
        { user_id: @user.id, metric_type: 'approval_rate', value: approval_rate, created_at: Time.current, updated_at: Time.current }
      ], unique_by: [:user_id, :metric_type])
  
      @user.update(processed: true)
    end
  end