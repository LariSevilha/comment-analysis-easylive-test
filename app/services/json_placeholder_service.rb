require 'net/http'
require 'json'

class JsonPlaceholderService
  BASE_URL = 'https://jsonplaceholder.typicode.com'.freeze

  def self.fetch_user_by_username(username)
    uri = URI("#{BASE_URL}/users?username=#{username}")
    response = Net::HTTP.get_response(uri)
    if response.is_a?(Net::HTTPSuccess)
      users = JSON.parse(response.body)
      users.find { |user| user['username'] == username }
    else
      Rails.logger.error "Failed to fetch user #{username}: #{response.code} #{response.message}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching user #{username}: #{e.message}"
    nil
  end

  def self.fetch_posts_by_user_id(user_id)
    uri = URI("#{BASE_URL}/posts?userId=#{user_id}")
    response = Net::HTTP.get_response(uri)
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "Failed to fetch posts for user_id #{user_id}: #{response.code} #{response.message}"
      []
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching posts for user_id #{user_id}: #{e.message}"
    []
  end

  def self.fetch_comments_by_post_id(post_id)
    uri = URI("#{BASE_URL}/comments?postId=#{post_id}")
    response = Net::HTTP.get_response(uri)
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "Failed to fetch comments for post_id #{post_id}: #{response.code} #{response.message}"
      []
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching comments for post_id #{post_id}: #{e.message}"
    []
  end
end