class ApplicationJob < ActiveJob::Base
  queue_as :default
  
  before_perform do |job|
    create_processing_job(job)
  end
  
  after_perform do |job|
    complete_processing_job(job)
  end
  
  rescue_from(Exception) do |exception|
    fail_processing_job(exception)
  end
  
  private
  
  def create_processing_job(job)
    @processing_job = ProcessingJob.create!(
      job_type: job.class.name,
      status: 'running',
      started_at: Time.current
    )
  end
  
  def complete_processing_job(job)
    @processing_job&.update!(
      status: 'completed',
      completed_at: Time.current
    )
  end
  
  def fail_processing_job(exception)
    @processing_job&.update!(
      status: 'failed',
      error_message: exception.message,
      completed_at: Time.current
    )
  end
end