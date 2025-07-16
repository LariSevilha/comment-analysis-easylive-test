class UserAnalysisService
  def initialize(username)
    @username = username&.to_s  
  end

  def analyze!
    Rails.logger.info "Creating AnalysisJob for username: #{@username}"

    unless @username.present?
      Rails.logger.error "Invalid username: #{@username.inspect}"
      raise ArgumentError, "Username cannot be blank"
    end

    job = AnalysisJob.create!(
      job_type: 'user_analysis',
      metadata: { username: @username },
      status: :pending,
      total_items: 0,
      processed_items: 0,
      progress_percentage: 0.0
    )

    Rails.logger.info "Enqueuing UserAnalysisJob with job_id: #{job.id}, username: #{@username}"
    UserAnalysisJob.perform_later(job.id, @username)

    job
  rescue StandardError => e
    Rails.logger.error "Failed to create AnalysisJob for #{@username}: #{e.message}\n#{e.backtrace.join("\n")}"
    raise
  end

  def self.import_user_data(username)
    user_data = JsonPlaceholderService.fetch_user_by_username(username)
    return nil unless user_data

    user = User.find_or_initialize_by(username: username)
    user.update!(
      name: user_data['name'],
      email: user_data['email'],
      external_id: user_data['id']
    )

    posts_data = JsonPlaceholderService.fetch_posts_by_user_id(user_data['id'])
    total_comments = 0

    posts_data.each do |post_data|
      post = user.posts.find_or_initialize_by(external_id: post_data['id'])
      post.update!(
        title: post_data['title'],
        body: post_data['body']
      )

      comments_data = JsonPlaceholderService.fetch_comments_by_post_id(post_data['id'])
      total_comments += comments_data.count

      comments_data.each do |comment_data|
        comment = post.comments.find_or_initialize_by(external_id: comment_data['id'])
        comment.update!(
          body: comment_data['body'],
          name: comment_data['name'] || 'Unknown',
          email: comment_data['email'] || 'unknown@example.com',
          user: user
        )
      end
    end

    [user, total_comments]
  end
end