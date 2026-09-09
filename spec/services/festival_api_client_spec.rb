require "rails_helper"

RSpec.describe FestivalApiClient do
  describe "#screenings_page" do
    it "returns a successful response body" do
      response = instance_double(Faraday::Response, success?: true, body: { "screenings" => [] })
      connection = instance_double(Faraday::Connection)
      allow(connection).to receive(:get)
        .with("/mock_api/screenings", { generation: 2, page: 3 })
        .and_return(response)

      body = described_class.new(connection: connection).screenings_page(page: 3, params: { generation: 2 })

      expect(body).to eq("screenings" => [])
    end

    it "raises a domain error for an unsuccessful response" do
      response = instance_double(Faraday::Response, success?: false, status: 500)
      connection = instance_double(Faraday::Connection, get: response)

      expect { described_class.new(connection: connection).screenings_page(page: 2) }
        .to raise_error(FestivalApiClient::Error, /HTTP 500.*page 2/)
    end

    it "wraps transport errors in a domain error" do
      connection = instance_double(Faraday::Connection)
      allow(connection).to receive(:get).and_raise(Faraday::TimeoutError, "execution expired")

      expect { described_class.new(connection: connection).screenings_page(page: 1) }
        .to raise_error(FestivalApiClient::Error, /request failed.*page 1/i)
    end
  end
end
