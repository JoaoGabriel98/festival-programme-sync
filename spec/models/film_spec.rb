require "rails_helper"

RSpec.describe Film, type: :model do
  it "requires a unique external id and a title" do
    create(:film, external_id: "FILM-001")

    expect(build(:film, external_id: nil)).not_to be_valid
    expect(build(:film, external_id: "FILM-001")).not_to be_valid
    expect(build(:film, title: nil)).not_to be_valid
  end
end
