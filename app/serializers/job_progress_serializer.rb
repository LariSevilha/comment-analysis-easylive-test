class JobProgressSerializer
  def self.serialize(job_tracker)
    {
      job_id: job_tracker.job_id, 
      status: job_tracker.status,
      progress: job_tracker.progress,
      total: job_tracker.total,
      error_message: job_tracker.error_message,
      job_type: job_tracker.job_type,
      metadata: job_tracker.metadata || {}
    }
  end
end