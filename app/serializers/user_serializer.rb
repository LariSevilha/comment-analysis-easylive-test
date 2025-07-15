class UserSerializer
    def initialize(user)
      @user = user
    end
    
    def as_json
      {
        id: @user.id,
        username: @user.username,
        name: @user.name,
        email: @user.email,
        total_comments: @user.total_comments,
        approved_comments: @user.approved_comments,
        rejected_comments: @user.rejected_comments,
        approval_rate: @user.approval_rate
      }
    end
  end