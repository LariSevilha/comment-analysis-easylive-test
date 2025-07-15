class Api::V1::MetricsController < ApplicationController
    def group
      group_metrics = GroupMetrics.latest
      
      if group_metrics
        render json: {
          group_metrics: group_metrics.metrics_data,
          calculated_at: group_metrics.calculated_at,
          total_users: group_metrics.total_users
        }
      else
        render json: { message: "No group metrics available" }
      end
    end
    
    def recalculate
      job = AnalysisJob.create!(job_type: 'recalculate_metrics')
      
      RecalculateAllUsersJob.perform_later

      
      render json: {
        message: "Metrics recalculation started",
        job_id: job.id,
        progress_url: api_v1_progress_url(job.id)
      }, status: :accepted
    end
  end