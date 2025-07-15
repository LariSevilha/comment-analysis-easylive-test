class UserAnalysisService
    def initialize(username)
      @username = username
    end
    
    def analyze!
      job = AnalysisJob.create!(job_type: 'user_analysis', metadata: { username: @username })
      
      UserAnalysisJob.perform_later(job.id, @username)
      
      job
    end
    
    def self.import_user_data(username)
      # Fetch user from JSONPlaceholder
      user_data = JsonPlaceholderService.fetch_user_by_username(username)
      return nil unless user_data
      
      # Create or update user
      user = User.find_or_initialize_by(username: username)
      user.update!(
        name: user_data['name'],
        email: user_data['email']
      )
      
      # Fetch and import posts
      posts_data = JsonPlaceholderService.fetch_posts_by_user_id(user_data['id'])
      
      posts_data.each do |post_data|
        post = user.posts.find_or_initialize_by(external_id: post_data['id'])
        post.update!(
          title: post_data['title'],
          body: post_data['body']
        )
         
        comments_data = JsonPlaceholderService.fetch_comments_by_post_id(post_data['id'])
        
        comments_data.each do |comment_data|
          comment = post.comments.find_or_initialize_by(external_id: comment_data['id'])
          comment.update!(
            name: comment_data['name'],
            email: comment_data['email'],
            body: comment_data['body']
          )
        end
      end
      
      user
    end
  end