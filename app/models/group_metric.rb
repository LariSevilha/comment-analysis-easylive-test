class GroupMetrics < ApplicationRecord
    def self.latest
      order(calculated_at: :desc).first
    end
    
    def self.calculate_and_store!
      users = User.analyzed.includes(:comments)
      
      if users.any?
        all_comments = Comment.processed.joins(post: :user).where(users: { id: users.ids })
        keyword_counts = all_comments.pluck(:matched_keywords_count)
        approval_counts = users.map(&:approved_comments)
        rejection_counts = users.map(&:rejected_comments)
        total_comment_counts = users.map(&:total_comments)
        
        metrics = {
          total_users: users.count,
          total_comments: all_comments.count,
          total_approved: all_comments.approved.count,
          total_rejected: all_comments.rejected.count,
          group_approval_rate: calculate_group_approval_rate(all_comments),
          keywords_distribution: {
            mean: keyword_counts.mean.round(2),
            median: keyword_counts.median.round(2),
            standard_deviation: keyword_counts.standard_deviation.round(2),
            variance: keyword_counts.variance.round(2),
            min: keyword_counts.min,
            max: keyword_counts.max
          },
          user_metrics: {
            approved_comments: {
              mean: approval_counts.mean.round(2),
              median: approval_counts.median.round(2),
              standard_deviation: approval_counts.standard_deviation.round(2)
            },
            rejected_comments: {
              mean: rejection_counts.mean.round(2),
              median: rejection_counts.median.round(2),
              standard_deviation: rejection_counts.standard_deviation.round(2)
            },
            total_comments: {
              mean: total_comment_counts.mean.round(2),
              median: total_comment_counts.median.round(2),
              standard_deviation: total_comment_counts.standard_deviation.round(2)
            }
          }
        }
        
        create!(metrics_data: metrics, total_users: users.count, calculated_at: Time.current)
      end
    end
    
    private
    
    def self.calculate_group_approval_rate(comments)
      return 0 if comments.empty?
      (comments.approved.count.to_f / comments.count * 100).round(2)
    end
  end