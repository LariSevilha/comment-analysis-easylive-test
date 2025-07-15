require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module CommentAnalysisApp
  class Application < Rails::Application
    config.load_defaults 7.0
    
    # API only
    config.api_only = true
    
    # Background jobs
    config.active_job.queue_adapter = :sidekiq 

    
    # Cache store
    config.cache_store = :redis_cache_store, { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }
    
    # Session store
    config.session_store :cache_store
    
    # Time zone
    config.time_zone = 'America/Sao_Paulo'
  end
end