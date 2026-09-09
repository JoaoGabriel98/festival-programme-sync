# Synchronizes the local programme with the external festival-management API.
class ProgrammeSync
  LOCK_KEY = 73_511_420
  RECORD_ERRORS = [KeyError, ArgumentError, ActiveRecord::RecordInvalid].freeze

  def initialize(client: FestivalApiClient.new, params: {})
    @client = client
    @params = params.to_h
    @created_count = 0
    @updated_count = 0
    @processed_count = 0
    @errors = []
  end

  def call
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      return skipped_run unless acquire_lock(connection)

      begin
        sync
      ensure
        release_lock(connection)
      end
    end
  end

  private

  def sync
    page = 1
    @run = ProgrammeSyncRun.create!(status: :running, started_at: Time.current)

    loop do
      response = @client.screenings_page(page: page, params: @params)
      process_records(response.fetch("screenings"), page: page)
      break if page >= response.fetch("total_pages").to_i

      page += 1
    end

    finish_run(@errors.any? ? :partial : :succeeded)
  rescue StandardError => e
    # Record-level errors are handled separately. Anything reaching here stops the run
    # so Sidekiq can retry API or infrastructure failures.
    capture_error(type: e.is_a?(FestivalApiClient::Error) ? "api" : "sync", page: page, message: e.message)
    finish_run(@processed_count.positive? ? :partial : :failed)
    raise
  end

  def process_records(records, page:)
    records.each do |payload|
      process_record(payload)
    rescue *RECORD_ERRORS => e
      capture_error(
        type: "record",
        page: page,
        external_id: payload.is_a?(Hash) ? payload["id"] : nil,
        message: e.message
      )
    end
  end

  def process_record(payload)
    changes = { created: 0, updated: 0 }

    # A screening and its nested film/venue are committed together. A malformed
    # record cannot roll back screenings that were already synchronized.
    ActiveRecord::Base.transaction do
      film_payload = payload.fetch("film")
      venue_payload = payload.fetch("venue")

      film = persist_record(
        Film,
        film_payload.fetch("id"),
        {
          title: film_payload.fetch("title"),
          synopsis: film_payload["synopsis"],
          runtime: film_payload["runtime"],
          year: film_payload["year"]
        },
        changes
      )

      venue = persist_record(
        Venue,
        venue_payload.fetch("id"),
        {
          name: venue_payload.fetch("name"),
          address: venue_payload["address"],
          capacity: venue_payload["capacity"]
        },
        changes
      )

      persist_record(
        Screening,
        payload.fetch("id"),
        {
          film: film,
          venue: venue,
          starts_at: payload.fetch("starts_at"),
          status: payload.fetch("status")
        },
        changes
      )
    end

    @created_count += changes[:created]
    @updated_count += changes[:updated]
    @processed_count += 1
  end

  def persist_record(model, external_id, attributes, changes)
    # External IDs are the stable identity from upstream. Names and titles may change.
    record = model.find_or_initialize_by(external_id: external_id)
    created = record.new_record?
    record.assign_attributes(attributes)

    return record unless record.changed?

    record.save!
    changes[created ? :created : :updated] += 1
    record
  end

  def capture_error(type:, message:, page:, external_id: nil)
    @errors << { type: type, page: page, external_id: external_id, message: message }.compact
  end

  def finish_run(status)
    return unless @run&.persisted?

    @run.update!(
      status: status,
      finished_at: Time.current,
      processed_count: @processed_count,
      created_count: @created_count,
      updated_count: @updated_count,
      error_count: @errors.size,
      error_details: @errors
    )
    @run
  end

  # Keep only one programme sync active at a time. PostgreSQL releases the lock
  # automatically if the database connection is lost.
  def acquire_lock(connection)
    connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_KEY})")
  end

  def release_lock(connection)
    connection.select_value("SELECT pg_advisory_unlock(#{LOCK_KEY})")
  end

  def skipped_run
    ProgrammeSyncRun.create!(
      status: :skipped,
      started_at: Time.current,
      finished_at: Time.current,
      error_details: [{ type: "overlap", message: "Another programme sync is already running" }],
      error_count: 1
    )
  end
end
