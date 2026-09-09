class CreateProgrammeSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :programme_sync_runs do |t|
      t.string :status, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :processed_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.jsonb :error_details, null: false, default: []

      t.timestamps
    end

    add_index :programme_sync_runs, :status
    add_index :programme_sync_runs, :started_at
  end
end
