require "rails_helper"

RSpec.describe ProgrammeSync do
  describe "#call" do
    it "imports every page using stable external identifiers" do
      run = sync_generation(1)

      expect(run).to be_succeeded
      expect(run).to have_attributes(
        processed_count: 60,
        created_count: 78,
        updated_count: 0,
        error_count: 0
      )
      expect(Film.count).to eq(12)
      expect(Venue.count).to eq(6)
      expect(Screening.count).to eq(60)
    end

    it "is idempotent when the same upstream data is synchronized twice" do
      sync_generation(1)

      second_run = nil
      expect { second_run = sync_generation(1) }
        .not_to change { [Film.count, Venue.count, Screening.count] }

      expect(second_run).to have_attributes(
        processed_count: 60,
        created_count: 0,
        updated_count: 0,
        error_count: 0
      )
    end

    it "updates renamed, moved and cancelled records while still inserting new screenings" do
      sync_generation(1)
      run = sync_generation(2)

      expect(Film.find_by!(external_id: "FILM-005").title).to eq("Autumn in Trieste (Director's Cut)")
      expect(Venue.find_by!(external_id: "VEN-03").name).to eq("City Gallery Auditorium")
      expect(Screening.find_by!(external_id: "SCR-0001").venue.external_id).to eq("VEN-06")
      expect(Screening.find_by!(external_id: "SCR-0010")).to be_cancelled
      expect(Screening.find_by(external_id: "SCR-0061")).to be_present
      expect(Screening.find_by(external_id: "SCR-0062")).to be_present

      expect(Film.where(external_id: "FILM-005").count).to eq(1)
      expect(Venue.where(external_id: "VEN-03").count).to eq(1)
      expect(run).to have_attributes(created_count: 2, updated_count: 9, error_count: 0)
    end

    it "keeps records from successful pages when the API fails later" do
      client = stub_client(
        records: MockApi::Dataset.generation_one,
        fail_on_page: 2,
        first_page_limit: 8
      )

      expect { described_class.new(client: client).call }
        .to raise_error(FestivalApiClient::Error, /unavailable/)

      expect(Screening.count).to eq(8)

      run = ProgrammeSyncRun.order(:id).last
      expect(run).to be_partial
      expect(run).to have_attributes(processed_count: 8, error_count: 1)
      expect(run.error_details.first).to include("type" => "api", "page" => 2)
    end

    it "isolates a bad record and continues with the rest of the page" do
      records = MockApi::Dataset.generation_one.first(3).map(&:deep_dup)
      records.second["status"] = "not-a-real-status"
      client = stub_client(records: records)

      run = described_class.new(client: client).call

      expect(run).to be_partial
      expect(run).to have_attributes(processed_count: 2, error_count: 1)
      expect(run.error_details.first).to include("type" => "record", "external_id" => "SCR-0002")
      expect(Screening.pluck(:external_id)).to contain_exactly("SCR-0001", "SCR-0003")
    end
  end

  def sync_generation(generation)
    records = MockApi::Dataset.records(generation: generation)
    client = stub_client(records: records)
    described_class.new(client: client, params: { generation: generation }).call
  end

  def stub_client(records:, fail_on_page: nil, first_page_limit: nil)
    client = instance_double(FestivalApiClient)

    allow(client).to receive(:screenings_page) do |page:, **_kwargs|
      raise FestivalApiClient::Error, "Upstream festival system unavailable" if page == fail_on_page

      per_page = MockApi::Dataset::PER_PAGE
      offset = (page - 1) * per_page
      page_records = if page == 1 && first_page_limit
        records.first(first_page_limit)
      else
        records[offset, per_page] || []
      end

      {
        "page" => page,
        "per_page" => per_page,
        "total_pages" => (records.size.to_f / per_page).ceil,
        "total_count" => records.size,
        "screenings" => page_records
      }
    end

    client
  end
end
