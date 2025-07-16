class Api::V1::JobsController < ApplicationController
  def index
    jobs = AnalysisJob.recent.limit(20)

    render json: {
      jobs: jobs.map do |job|
        {
          job_id: job.id,
          job_type: job.job_type,
          status: job.status,
          progress_percentage: job.progress_percentage || 0.0,
          created_at: job.created_at,
          completed_at: job.completed_at
        }
      end
    }
  end
end