class Api::V1::JobsController < ApplicationController
  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    
    jobs = AnalysisJob.order(created_at: :desc)
                     .page(page)
                     .per(per_page)
    
    render json: {
      jobs: jobs.map do |job|
        {
          id: job.id,
          job_type: job.job_type,
          status: job.status,
          progress_percentage: job.progress_percentage,
          processed_items: job.processed_items,
          total_items: job.total_items,
          metadata: job.metadata,
          current_step: job.metadata['current_step'],
          created_at: job.created_at,
          started_at: job.started_at,
          completed_at: job.completed_at,
          error_message: job.error_message
        }
      end,
      pagination: {
        current_page: jobs.current_page,
        total_pages: jobs.total_pages,
        total_count: jobs.total_count,
        per_page: per_page
      }
    }
  end
end