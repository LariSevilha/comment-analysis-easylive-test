class Api::V1::HealthController < Api::V1::BaseController
    def show
      render_success({
        status: 'healthy',
        version: '1.0.0',
        timestamp: Time.current.iso8601,
        database: database_status,
        cache: cache_status,
        background_jobs: background_jobs_status
      })
    end
    
    private
    
    def database_status
      User.connection.active? ? 'connected' : 'disconnected'
    rescue
      'error'
    end
    
    def cache_status
      Rails.cache.exist?('health_check') ? 'active' : 'inactive'
    rescue
      'error'
    end
    
    def background_jobs_status
      {
        pending: ProcessingJob.pending.count,
        running: ProcessingJob.running.count,
        completed: ProcessingJob.completed.count,
        failed: ProcessingJob.failed.count
      }
    rescue
      'error'
    end
  end