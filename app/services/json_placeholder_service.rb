class JsonPlaceholderService
    include HTTParty
    
    base_uri 'https://jsonplaceholder.typicode.com'
    
    def self.fetch_user_by_username(username)
      response = get('/users')
      users = response.parsed_response
      users.find { |user| user['username'] == username }
    end
    
    def self.fetch_posts_by_user_id(user_id)
      response = get("/users/#{user_id}/posts")
      response.parsed_response
    end
    
    def self.fetch_comments_by_post_id(post_id)
      response = get("/posts/#{post_id}/comments")
      response.parsed_response
    end
end