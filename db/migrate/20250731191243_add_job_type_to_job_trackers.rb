class AddJobTypeToJobTrackers < ActiveRecord::Migration[7.1]
  def change
    add_column :job_trackers, :job_type, :string
  end
end
