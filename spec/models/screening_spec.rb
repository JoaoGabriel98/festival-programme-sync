require "rails_helper"

RSpec.describe Screening, type: :model do
  it "requires a unique external id and start time" do
    create(:screening, external_id: "SCR-0001")

    expect(build(:screening, external_id: nil)).not_to be_valid
    expect(build(:screening, external_id: "SCR-0001")).not_to be_valid
    expect(build(:screening, starts_at: nil)).not_to be_valid
  end
end
