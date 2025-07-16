class MetricsSerializer
  def self.serialize_user_metrics(user_metrics)
    {
      user_id: user_metrics[:user_id],
      user_name: user_metrics[:user_name],
      comments: {
        total: user_metrics[:total_comments],
        approved: user_metrics[:approved_comments],
        rejected: user_metrics[:rejected_comments],
        processing: user_metrics[:processing_comments]
      },
      keyword_statistics: {
        all_comments: {
          average: user_metrics[:avg_keyword_count],
          median: user_metrics[:median_keyword_count],
          standard_deviation: user_metrics[:std_dev_keyword_count]
        },
        approved_comments: {
          average: user_metrics[:avg_approved_keyword_count],
          median: user_metrics[:median_approved_keyword_count],
          standard_deviation: user_metrics[:std_dev_approved_keyword_count]
        }
      },
      rates: {
        approval_rate: user_metrics[:approval_rate],
        rejection_rate: user_metrics[:rejection_rate]
      },
      calculated_at: user_metrics[:calculated_at]&.iso8601
    }
  end

  def self.serialize_group_metrics(group_metrics)
    {
      users: {
        total: group_metrics[:total_users],
        with_comments: group_metrics[:users_with_comments]
      },
      comments: {
        total: group_metrics[:total_comments],
        approved: group_metrics[:approved_comments],
        rejected: group_metrics[:rejected_comments],
        processing: group_metrics[:processing_comments]
      },
      keyword_statistics: {
        all_comments: {
          average: group_metrics[:avg_keyword_count],
          median: group_metrics[:median_keyword_count],
          standard_deviation: group_metrics[:std_dev_keyword_count]
        },
        approved_comments: {
          average: group_metrics[:avg_approved_keyword_count],
          median: group_metrics[:median_approved_keyword_count],
          standard_deviation: group_metrics[:std_dev_approved_keyword_count]
        }
      },
      comments_per_user: {
        average: group_metrics[:avg_comments_per_user],
        median: group_metrics[:median_comments_per_user],
        standard_deviation: group_metrics[:std_dev_comments_per_user]
      },
      rates: {
        approval_rate: group_metrics[:approval_rate],
        rejection_rate: group_metrics[:rejection_rate]
      },
      calculated_at: group_metrics[:calculated_at]&.iso8601
    }
  end
end
