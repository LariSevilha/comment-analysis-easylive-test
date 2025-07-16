class RequestContext
  CONTEXT_KEY = :request_context

  class << self
    def set(context = {})
      Thread.current[CONTEXT_KEY] = context.merge(timestamp: Time.current.iso8601)
    end

    def get
      Thread.current[CONTEXT_KEY] || {}
    end

    def clear
      Thread.current[CONTEXT_KEY] = nil
    end

    def with_context(context = {})
      old_context = get
      set(old_context.merge(context))
      yield
    ensure
      Thread.current[CONTEXT_KEY] = old_context
    end

    # Helper methods for common context data
    def request_id
      get[:request_id]
    end

    def user_id
      get[:user_id]
    end

    def job_id
      get[:job_id]
    end

    def add_context(additional_context)
      current = get
      set(current.merge(additional_context))
    end
  end
end
