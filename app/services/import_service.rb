require 'net/http'
require 'timeout'

class ImportService
  include HTTParty

  base_uri 'https://jsonplaceholder.typicode.com'

  # Configuration for retry logic
  MAX_RETRIES = 3
  RETRY_DELAY = 1 # seconds

  class ImportError < StandardError; end
  class UserNotFoundError < ImportError; end
  class APIError < ImportError; end

  def initialize
    @retry_count = 0
    @circuit_breaker = CircuitBreaker.for_service(:jsonplaceholder)
  end

  # Main method to import user and all related data
  def import_user_by_username(username)
    Rails.logger.info "Starting import for username: #{username}"

    # Find user by username from JSONPlaceholder
    user_data = fetch_user_by_username(username)
    raise UserNotFoundError, "User with username '#{username}' not found" unless user_data

    # Import or update user
    user = import_user(user_data)

    # Import posts for this user
    posts_data = fetch_user_posts(user_data['id'])
    imported_posts = import_posts(user, posts_data)

    # Import comments for each post
    total_comments = 0
    imported_posts.each do |post|
      comments_data = fetch_post_comments(post.external_id)
      imported_comments = import_comments(post, comments_data)
      total_comments += imported_comments.count
    end

    Rails.logger.info "Import completed for #{username}: #{imported_posts.count} posts, #{total_comments} comments"

    {
      user: user,
      posts_count: imported_posts.count,
      comments_count: total_comments
    }
  rescue => e
    Rails.logger.error "Import failed for #{username}: #{e.message}"
    raise
  end

  private

  # Fetch user by username from JSONPlaceholder API
  def fetch_user_by_username(username)
    @circuit_breaker.call do
      with_retry do
        Rails.logger.debug "Fetching user by username: #{username}"
        response = self.class.get('/users')

        raise APIError, "Failed to fetch users: #{response.code}" unless response.success?

        users = response.parsed_response
        user = users.find { |u| u['username'].downcase == username.downcase }

        Rails.logger.debug "User found: #{user ? user['id'] : 'none'}"
        user
      end
    end
  end

  # Fetch posts for a specific user ID
  def fetch_user_posts(user_id)
    @circuit_breaker.call do
      with_retry do
        Rails.logger.debug "Fetching posts for user ID: #{user_id}"
        response = self.class.get("/users/#{user_id}/posts")

        raise APIError, "Failed to fetch posts: #{response.code}" unless response.success?

        posts = response.parsed_response
        Rails.logger.debug "Found #{posts.count} posts for user #{user_id}"
        posts
      end
    end
  end

  # Fetch comments for a specific post ID
  def fetch_post_comments(post_id)
    @circuit_breaker.call do
      with_retry do
        Rails.logger.debug "Fetching comments for post ID: #{post_id}"
        response = self.class.get("/posts/#{post_id}/comments")

        raise APIError, "Failed to fetch comments: #{response.code}" unless response.success?

        comments = response.parsed_response
        Rails.logger.debug "Found #{comments.count} comments for post #{post_id}"
        comments
      end
    end
  end

  # Import or update user record
  def import_user(user_data)
    user = User.find_or_initialize_by(external_id: user_data['id'])

    user.assign_attributes(
      name: user_data['name'],
      username: user_data['username'],
      email: user_data['email']
    )

    if user.new_record?
      Rails.logger.info "Creating new user: #{user_data['name']} (#{user_data['username']})"
    else
      Rails.logger.info "Updating existing user: #{user_data['name']} (#{user_data['username']})"
    end

    user.save!
    user
  end

  # Import posts for a user
  def import_posts(user, posts_data)
    imported_posts = []

    posts_data.each do |post_data|
      post = Post.find_or_initialize_by(external_id: post_data['id'])

      post.assign_attributes(
        user: user,
        title: post_data['title'],
        body: post_data['body']
      )

      if post.new_record?
        Rails.logger.debug "Creating new post: #{post_data['title'][0..50]}..."
      else
        Rails.logger.debug "Updating existing post: #{post_data['title'][0..50]}..."
      end

      post.save!
      imported_posts << post
    end

    imported_posts
  end

  # Import comments for a post
  def import_comments(post, comments_data)
    imported_comments = []

    comments_data.each do |comment_data|
      comment = Comment.find_or_initialize_by(external_id: comment_data['id'])

      comment.assign_attributes(
        post: post,
        name: comment_data['name'],
        email: comment_data['email'],
        body: comment_data['body']
      )

      if comment.new_record?
        Rails.logger.debug "Creating new comment: #{comment_data['name'][0..30]}..."
      else
        Rails.logger.debug "Updating existing comment: #{comment_data['name'][0..30]}..."
      end

      comment.save!
      imported_comments << comment
    end

    imported_comments
  end

  # Retry logic wrapper for API calls
  def with_retry
    @retry_count = 0

    begin
      yield
    rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
      @retry_count += 1

      if @retry_count <= MAX_RETRIES
        Rails.logger.warn "API call failed (attempt #{@retry_count}/#{MAX_RETRIES}): #{e.message}. Retrying in #{RETRY_DELAY} seconds..."
        sleep(RETRY_DELAY * @retry_count) # Exponential backoff
        retry
      else
        Rails.logger.error "API call failed after #{MAX_RETRIES} attempts: #{e.message}"
        raise APIError, "API unavailable after #{MAX_RETRIES} attempts: #{e.message}"
      end
    rescue HTTParty::Error => e
      Rails.logger.error "HTTParty error: #{e.message}"
      raise APIError, "HTTP request failed: #{e.message}"
    end
  end
end
