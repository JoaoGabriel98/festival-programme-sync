require "rails_helper"

RSpec.describe Venue, type: :model do
  it "requires a unique external id and a name" do
    create(:venue, external_id: "VEN-01")

    expect(build(:venue, external_id: nil)).not_to be_valid
    expect(build(:venue, external_id: "VEN-01")).not_to be_valid
    expect(build(:venue, name: nil)).not_to be_valid
  end
end
