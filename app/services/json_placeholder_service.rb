class JsonPlaceholderService
    BASE_URL = 'https://jsonplaceholder.typicode.com'
    
    def self.fetch_user_by_username(username)
      response = Faraday.get("#{BASE_URL}/users")
      users = JSON.parse(response.body)
      users.find { |user| user['username'].downcase == username.downcase }
    end
    
    def self.fetch_user_posts(user_id)
      response = Faraday.get("#{BASE_URL}/posts?userId=#{user_id}")
      JSON.parse(response.body)
    end
    
    def self.fetch_post_comments(post_id)
      response = Faraday.get("#{BASE_URL}/comments?postId=#{post_id}")
      JSON.parse(response.body)
    end
    
    def self.import_user_data(username)
      user_data = fetch_user_by_username(username)
      return nil unless user_data
      
      user = User.find_or_create_by(external_id: user_data['id']) do |u|
        u.username = user_data['username']
        u.name = user_data['name']
        u.email = user_data['email']
        u.address = user_data['address'].to_json
        u.phone = user_data['phone']
        u.website = user_data['website']
        u.company = user_data['company'].to_json
      end
      
      import_user_posts(user, user_data['id'])
      user
    end
    
    private
    
    def self.import_user_posts(user, external_user_id)
      posts_data = fetch_user_posts(external_user_id)
      
      posts_data.each do |post_data|
        post = Post.find_or_create_by(external_id: post_data['id']) do |p|
          p.user = user
          p.title = post_data['title']
          p.body = post_data['body']
        end
        
        import_post_comments(post, post_data['id'])
      end
    end
    
    def self.import_post_comments(post, external_post_id)
      comments_data = fetch_post_comments(external_post_id)
      
      comments_data.each do |comment_data|
        comment = Comment.find_or_create_by(external_id: comment_data['id']) do |c|
          c.post = post
          c.name = comment_data['name']
          c.email = comment_data['email']
          c.body = comment_data['body']
        end
        
        comment.process_classification! if comment.persisted? && comment.new?
      end
    end
  end