require 'test_helper'
require 'net/http'

class ImportServiceTest < ActiveSupport::TestCase
  def setup
    @service = ImportService.new
    @sample_user_data = {
      'id' => 1,
      'name' => 'Leanne Graham',
      'username' => 'Bret',
      'email' => 'Sincere@april.biz'
    }
    @sample_post_data = {
      'id' => 1,
      'userId' => 1,
      'title' => 'Sample Post Title',
      'body' => 'Sample post body content'
    }
    @sample_comment_data = {
      'id' => 1,
      'postId' => 1,
      'name' => 'Sample Comment',
      'email' => 'commenter@example.com',
      'body' => 'Sample comment body'
    }
  end

  test "should import user by username successfully" do
    # Mock API responses
    users_response = mock_response([@sample_user_data])
    posts_response = mock_response([@sample_post_data])
    comments_response = mock_response([@sample_comment_data])

    ImportService.expects(:get).with('/users').returns(users_response)
    ImportService.expects(:get).with('/users/1/posts').returns(posts_response)
    ImportService.expects(:get).with('/posts/1/comments').returns(comments_response)

    result = @service.import_user_by_username('Bret')

    assert_not_nil result[:user]
    assert_equal 1, result[:posts_count]
    assert_equal 1, result[:comments_count]

    # Verify user was created
    user = User.find_by(external_id: 1)
    assert_not_nil user
    assert_equal 'Leanne Graham', user.name
    assert_equal 'Sincere@april.biz', user.email

    # Verify post was created
    post = Post.find_by(external_id: 1)
    assert_not_nil post
    assert_equal user, post.user
    assert_equal 'Sample Post Title', post.title

    # Verify comment was created
    comment = Comment.find_by(external_id: 1)
    assert_not_nil comment
    assert_equal post, comment.post
    assert_equal 'Sample Comment', comment.name
    assert_equal 'new', comment.status
  end

  test "should raise UserNotFoundError when username not found" do
    users_response = mock_response([])
    ImportService.expects(:get).with('/users').returns(users_response)

    assert_raises(ImportService::UserNotFoundError) do
      @service.import_user_by_username('NonExistentUser')
    end
  end

  test "should handle case insensitive username search" do
    users_response = mock_response([@sample_user_data])
    posts_response = mock_response([])
    comments_response = mock_response([])

    ImportService.expects(:get).with('/users').returns(users_response)
    ImportService.expects(:get).with('/users/1/posts').returns(posts_response)

    # Test with different case
    result = @service.import_user_by_username('BRET')

    assert_not_nil result[:user]
    assert_equal 'Leanne Graham', result[:user].name
  end

  test "should avoid duplicates using external_id" do
    # Create existing user
    existing_user = User.create!(
      name: 'Old Name',
      username: 'oldname',
      email: 'old@email.com',
      external_id: 1
    )

    users_response = mock_response([@sample_user_data])
    posts_response = mock_response([])

    ImportService.expects(:get).with('/users').returns(users_response)
    ImportService.expects(:get).with('/users/1/posts').returns(posts_response)

    result = @service.import_user_by_username('Bret')

    # Should update existing user, not create new one
    assert_equal existing_user.id, result[:user].id
    assert_equal 'Leanne Graham', result[:user].name # Updated name
    assert_equal 'Sincere@april.biz', result[:user].email # Updated email
    assert_equal 1, User.count # Still only one user
  end

  test "should avoid duplicate posts using external_id" do
    user = User.create!(name: 'Test User', username: "testeuser", email: 'test@example.com', external_id: 1)
    existing_post = Post.create!(
      user: user,
      title: 'Old Title',
      body: 'Old Body',
      external_id: 1
    )

    users_response = mock_response([@sample_user_data])
    posts_response = mock_response([@sample_post_data])
    comments_response = mock_response([])

    ImportService.expects(:get).with('/users').returns(users_response)
    ImportService.expects(:get).with('/users/1/posts').returns(posts_response)
    ImportService.expects(:get).with('/posts/1/comments').returns(comments_response)

    @service.import_user_by_username('Bret')

    # Should update existing post, not create new one
    existing_post.reload
    assert_equal 'Sample Post Title', existing_post.title # Updated
    assert_equal 1, Post.count # Still only one post
  end

  test "should avoid duplicate comments using external_id" do
    user = User.create!(name: 'Test User', username: "testuser", email: 'test@example.com', external_id: 1)
    post = Post.create!(user: user, title: 'Test Post', body: 'Test Body', external_id: 1)
    existing_comment = Comment.create!(
      post: post,
      name: 'Old Comment',
      email: 'old@example.com',
      body: 'Old comment body',
      external_id: 1
    )

    users_response = mock_response([@sample_user_data])
    posts_response = mock_response([@sample_post_data])
    comments_response = mock_response([@sample_comment_data])

    ImportService.expects(:get).with('/users').returns(users_response)
    ImportService.expects(:get).with('/users/1/posts').returns(posts_response)
    ImportService.expects(:get).with('/posts/1/comments').returns(comments_response)

    @service.import_user_by_username('Bret')

    # Should update existing comment, not create new one
    existing_comment.reload
    assert_equal 'Sample Comment', existing_comment.name # Updated
    assert_equal 1, Comment.count # Still only one comment
  end

  test "should retry on network errors" do
    users_response = mock_response([@sample_user_data])
    posts_response = mock_response([])

    # Create a sequence for the retry behavior
    sequence = sequence('retry_sequence')
    ImportService.expects(:get).with('/users').raises(Timeout::Error).in_sequence(sequence)
    ImportService.expects(:get).with('/users').returns(users_response).in_sequence(sequence)
    ImportService.expects(:get).with('/users/1/posts').returns(posts_response)

    # Should not raise error due to retry logic
    result = @service.import_user_by_username('Bret')
    assert_not_nil result[:user]
  end

  test "should raise APIError after max retries exceeded" do
    # All calls fail
    ImportService.expects(:get).with('/users').raises(Timeout::Error).times(4) # Initial + 3 retries

    assert_raises(ImportService::APIError) do
      @service.import_user_by_username('Bret')
    end
  end

  test "should raise APIError on HTTP error responses" do
    error_response = mock('response')
    error_response.stubs(:success?).returns(false)
    error_response.stubs(:code).returns(500)

    ImportService.expects(:get).with('/users').returns(error_response)

    assert_raises(ImportService::APIError) do
      @service.import_user_by_username('Bret')
    end
  end

  test "should handle multiple posts and comments" do
    post1_data = @sample_post_data.merge('id' => 1, 'title' => 'Post 1')
    post2_data = @sample_post_data.merge('id' => 2, 'title' => 'Post 2')

    comment1_data = @sample_comment_data.merge('id' => 1, 'postId' => 1, 'name' => 'Comment 1')
    comment2_data = @sample_comment_data.merge('id' => 2, 'postId' => 1, 'name' => 'Comment 2')
    comment3_data = @sample_comment_data.merge('id' => 3, 'postId' => 2, 'name' => 'Comment 3')

    users_response = mock_response([@sample_user_data])
    posts_response = mock_response([post1_data, post2_data])
    comments1_response = mock_response([comment1_data, comment2_data])
    comments2_response = mock_response([comment3_data])

    ImportService.expects(:get).with('/users').returns(users_response)
    ImportService.expects(:get).with('/users/1/posts').returns(posts_response)
    ImportService.expects(:get).with('/posts/1/comments').returns(comments1_response)
    ImportService.expects(:get).with('/posts/2/comments').returns(comments2_response)

    result = @service.import_user_by_username('Bret')

    assert_equal 2, result[:posts_count]
    assert_equal 3, result[:comments_count]

    # Verify all records were created
    assert_equal 1, User.count
    assert_equal 2, Post.count
    assert_equal 3, Comment.count
  end

  private

  def mock_response(data)
    response = mock('response')
    response.stubs(:success?).returns(true)
    response.stubs(:parsed_response).returns(data)
    response
  end
end
