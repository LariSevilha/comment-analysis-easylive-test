class JobProgressSerializer
  def self.serialize(job_tracker)
    {
      job_id: job_tracker.job_id,
      status: job_tracker.status,
      progress: job_tracker.progress,
      total: job_tracker.total,
      progress_percentage: job_tracker.progress_percentage,
      error_message: job_tracker.error_message,
      metadata: parse_metadata(job_tracker.metadata),
      created_at: job_tracker.created_at.iso8601,
      updated_at: job_tracker.updated_at.iso8601
    }
  end

  private

  def self.parse_metadata(metadata_json)
    return {} if metadata_json.blank?

    case metadata_json
    when Hash
      metadata_json
    when String
      JSON.parse(metadata_json)
    else
      {}
    end
  rescue JSON::ParserError
    {}
  end
end
