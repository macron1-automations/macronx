require 'rails_helper'

RSpec.describe Inboxes::ProcessJob, type: :job do
  include ActiveJob::TestHelper

  let!(:tag) { create(:tag, name: 'research') }
  let!(:workflow) { create(:workflow, tag: tag) }
  let(:inbox) { create(:inbox, tag: tag) }

  before do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  describe '#perform' do
    it 'returns without error if inbox does not exist' do
      expect {
        described_class.perform_now(0)
      }.not_to raise_error

      expect(Workflows::RunJob).not_to have_been_enqueued
    end

    it 'runs audio and image conversions and enqueues Workflows::RunJob once' do
      allow(Audio::ConvertM4aToMp3Job).to receive(:perform_now).with(inbox.id)
      allow(Image::ConvertHeicToJpegJob).to receive(:perform_now).with(inbox.id)

      described_class.perform_now(inbox.id)

      expect(Audio::ConvertM4aToMp3Job).to have_received(:perform_now).with(inbox.id)
      expect(Image::ConvertHeicToJpegJob).to have_received(:perform_now).with(inbox.id)
      expect(Workflows::RunJob).to have_been_enqueued.with(inbox.id).once
    end

    it 'runs conversion pipeline end-to-end and enqueues Workflows::RunJob once' do
      described_class.perform_now(inbox.id)

      expect(Workflows::RunJob).to have_been_enqueued.with(inbox.id).once
    end
  end
end
