require "rails_helper"

RSpec.describe ProgrammeSyncRun, type: :model do
  it "requires a status, start time and non-negative counters" do
    run = described_class.new(status: :running, started_at: Time.current)

    expect(run).to be_valid

    run.processed_count = -1
    expect(run).not_to be_valid
  end
end
