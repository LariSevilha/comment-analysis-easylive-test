class Api::V1::ProgressController < Api::V1::BaseController
  def index
    jobs = ProcessingJob.recent.limit(20)
    
    render_success({
      jobs: jobs.map do |job|
        {
          id: job.id,
          type: job.job_type,
          status: job.status,
          progress: calculate_progress(job),
          progress_info: job.progress_info,
          error_message: job.error_message,
          started_at: job.started_at,
          completed_at: job.completed_at,
          created_at: job.created_at
        }
      end
    })
  end
  
  def show
    job = ProcessingJob.find(params[:id])
    
    render_success({
      id: job.id,
      type: job.job_type,
      status: job.status,
      progress: calculate_progress(job),
      progress_info: job.progress_info,
      error_message: job.error_message,
      total_items: job.total_items,
      processed_items: job.processed_items,
      started_at: job.started_at,
      completed_at: job.completed_at,
      created_at: job.created_at
    })
  end
  
  private
  
  def calculate_progress(job)
    return 100 if job.completed? || job.failed?
    return 0 if job.total_items == 0
    
    (job.processed_items.to_f / job.total_items * 100).round(2)
  end
end