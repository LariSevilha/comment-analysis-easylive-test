class RecalculateGroupMetricsService
    def call
      users = User.processed
      total_users = users.count
      total_comments = users.sum(:comments_count)
      total_approved = users.sum(:approved_comments_count)
      total_rejected = users.sum(:rejected_comments_count)
  
      overall_approval_rate = total_comments.positive? ? (total_approved.to_f / total_comments) * 100 : 0
  
      GroupMetric.create!(data: {
        total_users_analyzed: total_users,
        total_comments_processed: total_comments,
        total_approved_comments: total_approved,
        total_rejected_comments: total_rejected,
        overall_approval_rate: overall_approval_rate
      })
    end
  end
  