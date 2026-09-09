# Small HTTP client for the external festival-management system.
# Keeping HTTP concerns here makes ProgrammeSync focused on persistence and lets
# the sync be tested without making network requests.
class FestivalApiClient
  class Error < StandardError; end

  DEFAULT_TIMEOUT = 10
  DEFAULT_OPEN_TIMEOUT = 2

  def initialize(base_url: ENV.fetch("FESTIVAL_API_URL", "http://localhost:3000"), connection: nil)
    @connection = connection || Faraday.new(url: base_url) do |faraday|
      faraday.response :json, content_type: /\bjson$/
      faraday.options.timeout = DEFAULT_TIMEOUT
      faraday.options.open_timeout = DEFAULT_OPEN_TIMEOUT
    end
  end

  def screenings_page(page:, params: {})
    response = @connection.get("/mock_api/screenings", params.merge(page: page))

    unless response.success?
      raise Error, "Festival API returned HTTP #{response.status} while fetching page #{page}"
    end

    response.body
  rescue Faraday::Error => e
    raise Error, "Festival API request failed on page #{page}: #{e.message}"
  end
end
