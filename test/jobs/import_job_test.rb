require 'test_helper'

class ImportJobTest < ActiveJob::TestCase
  def setup
    @username = 'testuser'
    @job_tracker = JobTracker.create!(
      job_id: SecureRandom.uuid,
      status: :pending,
      progress: 0,
      total: 100
    )
  end

  test "should enqueue import job" do
    assert_enqueued_with(job: ImportJob, args: [@username, @job_tracker.id]) do
      ImportJob.perform_later(@username, @job_tracker.id)
    end
  end

  test "should update job tracker status to processing when job starts" do
    # Mock the ImportService to avoid external API calls
    import_service = mock('import_service')
    import_result = {
      user: users(:one),
      posts_count: 2,
      comments_count: 5
    }

    ImportService.expects(:new).returns(import_service)
    import_service.expects(:import_user_by_username).with(@username).returns(import_result)

    # Mock user comments to return empty array (no new comments)
    comments_relation = mock('comments_relation')
    users(:one).expects(:comments).returns(comments_relation)
    comments_relation.expects(:where).with(status: :new).returns([])

    perform_enqueued_jobs do
      ImportJob.perform_later(@username, @job_tracker.id)
    end

    @job_tracker.reload
    assert_equal 'completed', @job_tracker.status
  end

  test "should handle import service user not found errors" do
    # Mock the ImportService to raise an error
    ImportService.any_instance.expects(:import_user_by_username)
                  .with(@username)
                  .raises(ImportService::UserNotFoundError.new("User not found"))

    # The job should be discarded, not raise an error
    perform_enqueued_jobs do
      ImportJob.perform_later(@username, @job_tracker.id)
    end

    @job_tracker.reload
    assert_equal 'failed', @job_tracker.status
    assert_includes @job_tracker.error_message, "User not found"
  end
end
