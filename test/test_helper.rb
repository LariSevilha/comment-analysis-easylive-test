ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "vcr"
require "webmock/minitest"
require "factory_bot_rails"

# Configure VCR for recording HTTP interactions
VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri, :body]
  }
  config.ignore_localhost = true
  config.allow_http_connections_when_no_cassette = false

  # Filter sensitive data
  config.filter_sensitive_data('<LIBRETRANSLATE_API_KEY>') { ENV['LIBRETRANSLATE_API_KEY'] }
  config.filter_sensitive_data('<LIBRETRANSLATE_URL>') { ENV['LIBRETRANSLATE_URL'] }
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Include Factory Bot methods
    include FactoryBot::Syntax::Methods

    # Add more helper methods to be used by all tests here...

    # Helper method to run jobs synchronously in tests
    def perform_enqueued_jobs_immediately
      old_perform_enqueued_jobs = ActiveJob::Base.queue_adapter.perform_enqueued_jobs
      old_perform_enqueued_at_jobs = ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs

      ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
      ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true

      yield
    ensure
      ActiveJob::Base.queue_adapter.perform_enqueued_jobs = old_perform_enqueued_jobs
      ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = old_perform_enqueued_at_jobs
    end
  end
end
