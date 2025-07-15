class Api::V1::ProgressController < ApplicationController
  def show
    job = AnalysisJob.find(params[:id])
    
    render json: {
      job_id: job.id,
      job_type: job.job_type,
      status: job.status,
      progress: {
        total_items: job.total_items,
        processed_items: job.processed_items,
        percentage: job.progress_percentage
      },
      started_at: job.started_at,
      completed_at: job.completed_at,
      error_message: job.error_message,
      metadata: job.metadata
    }
  end
  
  def index
    jobs = AnalysisJob.order(created_at: :desc).limit(20)
    
    render json: {
      jobs: jobs.map do |job|
        {
          job_id: job.id,
          job_type: job.job_type,
          status: job.status,
          progress_percentage: job.progress_percentage,
          created_at: job.created_at,
          completed_at: job.completed_at
        }
      end
    }
  end
end