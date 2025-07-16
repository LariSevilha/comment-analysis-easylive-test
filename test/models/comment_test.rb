require "test_helper"

class CommentTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: 'Test User',
      username: 'testuser',
      email: "test@example.com",
      external_id: 1
    )

    @post = Post.create!(
      title: "Test Post",
      body: "Test post body",
      external_id: 1,
      user: @user
    )

    @comment = Comment.create!(
      name: "Test Commenter",
      email: "commenter@example.com",
      body: "This is a test comment",
      external_id: 1,
      post: @post
    )
  end

  # Test initial state
  test "should have initial state as new" do
    assert @comment.new?
    assert_equal "new", @comment.status
  end

  # Test state transitions
  test "should transition from new to processing" do
    assert @comment.may_start_processing?
    assert @comment.start_processing!
    assert @comment.processing?
    assert_equal "processing", @comment.status
  end

  test "should transition from processing to approved" do
    @comment.start_processing!
    assert @comment.may_approve?
    assert @comment.approve!
    assert @comment.approved?
    assert_equal "approved", @comment.status
  end

  test "should transition from processing to rejected" do
    @comment.start_processing!
    assert @comment.may_reject?
    assert @comment.reject!
    assert @comment.rejected?
    assert_equal "rejected", @comment.status
  end

  # Test invalid transitions
  test "should not transition from new to approved directly" do
    assert_not @comment.may_approve?
    assert_raises(AASM::InvalidTransition) { @comment.approve! }
  end

  test "should not transition from new to rejected directly" do
    assert_not @comment.may_reject?
    assert_raises(AASM::InvalidTransition) { @comment.reject! }
  end

  test "should not transition from approved back to processing" do
    @comment.start_processing!
    @comment.approve!
    assert_not @comment.may_start_processing?
    assert_raises(AASM::InvalidTransition) { @comment.start_processing! }
  end

  test "should not transition from rejected back to processing" do
    @comment.start_processing!
    @comment.reject!
    assert_not @comment.may_start_processing?
    assert_raises(AASM::InvalidTransition) { @comment.start_processing! }
  end

  # Test guards through state transitions
  test "should not start processing if required fields are missing" do
    comment_without_body = Comment.create!(
      name: "Test",
      email: "test@example.com",
      body: "Valid body", # Need valid body to create
      external_id: 2,
      post: @post
    )

    # Now remove body to test guard
    comment_without_body.update_column(:body, nil)
    assert_not comment_without_body.may_start_processing?
  end

  test "should not approve if no translated body or original body" do
    @comment.start_processing!
    # Remove both body and translated_body to test guard
    @comment.update_columns(body: nil, translated_body: nil)
    assert_not @comment.may_approve?
  end

  test "should approve if translated body is present" do
    @comment.start_processing!
    @comment.update!(translated_body: "Translated comment")
    assert @comment.may_approve?
  end

  test "should approve if original body is present even without translation" do
    @comment.start_processing!
    assert @comment.may_approve?
  end

  test "should always be able to reject from processing state" do
    @comment.start_processing!
    assert @comment.may_reject?
  end

  # Test callbacks and logging
  test "should log when starting processing" do
    Rails.logger.expects(:info).with(
      "Comment #{@comment.id} started processing - User: #{@user.name}, Post: #{@post.id}"
    )
    @comment.start_processing!
  end

  test "should log when approving" do
    @comment.start_processing!
    @comment.update!(keyword_count: 3)

    Rails.logger.expects(:info).with(
      "Comment #{@comment.id} approved - Keyword count: 3, User: #{@user.name}"
    )
    @comment.approve!
  end

  test "should log when rejecting" do
    @comment.start_processing!
    @comment.update!(keyword_count: 1)

    Rails.logger.expects(:info).with(
      "Comment #{@comment.id} rejected - Keyword count: 1, User: #{@user.name}"
    )
    @comment.reject!
  end

  test "should handle nil keyword_count in logging" do
    @comment.start_processing!

    Rails.logger.expects(:info).with(
      "Comment #{@comment.id} approved - Keyword count: 0, User: #{@user.name}"
    )
    @comment.approve!
  end

  # Test state queries
  test "should respond to state query methods" do
    assert @comment.new?
    assert_not @comment.processing?
    assert_not @comment.approved?
    assert_not @comment.rejected?

    @comment.start_processing!
    assert_not @comment.new?
    assert @comment.processing?
    assert_not @comment.approved?
    assert_not @comment.rejected?

    @comment.approve!
    assert_not @comment.new?
    assert_not @comment.processing?
    assert @comment.approved?
    assert_not @comment.rejected?
  end

  # Test event methods
  test "should respond to event methods" do
    assert_respond_to @comment, :start_processing!
    assert_respond_to @comment, :approve!
    assert_respond_to @comment, :reject!
    assert_respond_to @comment, :may_start_processing?
    assert_respond_to @comment, :may_approve?
    assert_respond_to @comment, :may_reject?
  end

  # Test complete workflow
  test "should complete full workflow from new to approved" do
    # Start as new
    assert @comment.new?

    # Move to processing
    @comment.start_processing!
    assert @comment.processing?

    # Add translation and keyword count
    @comment.update!(translated_body: "Comentário traduzido", keyword_count: 3)

    # Approve
    @comment.approve!
    assert @comment.approved?
  end

  test "should complete full workflow from new to rejected" do
    # Start as new
    assert @comment.new?

    # Move to processing
    @comment.start_processing!
    assert @comment.processing?

    # Add translation with low keyword count
    @comment.update!(translated_body: "Comentário traduzido", keyword_count: 1)

    # Reject
    @comment.reject!
    assert @comment.rejected?
  end

  # Test guard conditions more thoroughly
  test "should not start processing if name is missing" do
    comment = Comment.create!(
      name: "Valid name",
      email: "test@example.com",
      body: "Valid body",
      external_id: 3,
      post: @post
    )

    comment.update_column(:name, nil)
    assert_not comment.may_start_processing?
  end

  test "should not start processing if email is missing" do
    comment = Comment.create!(
      name: "Valid name",
      email: "test@example.com",
      body: "Valid body",
      external_id: 4,
      post: @post
    )

    comment.update_column(:email, nil)
    assert_not comment.may_start_processing?
  end

  test "should start processing when all required fields are present" do
    assert @comment.may_start_processing?
    assert @comment.start_processing!
  end

  # Test that guards prevent invalid transitions
  test "should prevent start_processing when guard fails" do
    @comment.update_column(:body, nil)
    assert_raises(AASM::InvalidTransition) { @comment.start_processing! }
  end

  test "should prevent approve when guard fails" do
    @comment.start_processing!
    @comment.update_columns(body: nil, translated_body: nil)
    assert_raises(AASM::InvalidTransition) { @comment.approve! }
  end
end
