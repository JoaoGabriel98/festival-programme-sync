# Scheduled entry point for the programme synchronization.
# API failures intentionally bubble up so Sidekiq can apply its normal retry policy.
class ProgrammeSyncJob < ApplicationJob
  queue_as :default

  def perform(params = {})
    ProgrammeSync.new(params: params).call
  end
end
