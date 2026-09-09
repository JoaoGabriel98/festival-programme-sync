class ProgrammeSyncRun < ApplicationRecord
  enum :status, {
    running: "running",
    succeeded: "succeeded",
    partial: "partial",
    failed: "failed",
    skipped: "skipped"
  }

  validates :status, :started_at, presence: true
  validates :processed_count, :created_count, :updated_count, :error_count,
    numericality: { greater_than_or_equal_to: 0 }
end
