require "rails_helper"

RSpec.describe ProgrammeSyncJob, type: :job do
  it "delegates the work to ProgrammeSync" do
    sync = instance_double(ProgrammeSync, call: true)
    allow(ProgrammeSync).to receive(:new).with(params: { "generation" => 2 }).and_return(sync)

    described_class.perform_now("generation" => 2)

    expect(sync).to have_received(:call)
  end
end
