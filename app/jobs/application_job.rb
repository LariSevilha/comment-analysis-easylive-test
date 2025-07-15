class ApplicationJob < ActiveJob::Base
  retry_on StandardError, wait: 10.seconds, attempts: 3
end
