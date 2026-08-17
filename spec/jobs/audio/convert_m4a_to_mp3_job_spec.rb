require 'rails_helper'

RSpec.describe Audio::ConvertM4aToMp3Job, type: :job do
  let!(:tag) { create(:tag, name: 'research') }
  let!(:workflow) { create(:workflow, tag: tag) }
  let(:inbox) { create(:inbox, tag: tag) }
  let(:transcription) { instance_double(RubyLLM::Transcription, text: 'Hello world') }

  before do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    allow(RubyLLM).to receive(:transcribe).and_return(transcription)
  end

  describe '#perform' do
    context 'with m4a attachments' do
      before do
        inbox.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/sample.m4a')),
          filename: 'voice.m4a',
          content_type: 'audio/mp4'
        )
      end

      it 'replaces m4a attachment with mp3' do
        allow_any_instance_of(described_class).to receive(:system).and_return(true)

        expect_any_instance_of(described_class).to receive(:system).with(
          'ffmpeg', '-i', anything, '-codec:a', 'libmp3lame', '-q:a', '2', anything, '-y', '-loglevel', 'error'
        )

        described_class.perform_now(inbox.id)

        inbox.reload
        expect(inbox.attachments.count).to eq(1)
        expect(inbox.attachments.first.content_type).to eq('audio/mpeg')
        expect(inbox.attachments.first.filename.to_s).to eq('voice.mp3')
      end

      it 'enqueues the workflow job after conversion' do
        allow_any_instance_of(described_class).to receive(:system).and_return(true)

        described_class.perform_now(inbox.id)

        expect(Workflows::RunJob).to have_been_enqueued
      end

      it 'transcribes audio and stores transcript in metadata' do
        allow_any_instance_of(described_class).to receive(:system).and_return(true)

        described_class.perform_now(inbox.id)

        inbox.reload
        expect(inbox.metadata['audio_transcript']).to eq('Hello world')
        expect(RubyLLM).to have_received(:transcribe).with(anything)
      end

      it 'raises when ffmpeg conversion fails' do
        allow_any_instance_of(described_class).to receive(:system).and_return(false)

        expect {
          described_class.perform_now(inbox.id)
        }.to raise_error(RuntimeError, /ffmpeg conversion failed/)

        inbox.reload
        expect(inbox.attachments.first.filename.to_s).to eq('voice.m4a')
        expect(inbox.attachments.first.content_type).to eq('audio/mp4')
      end
    end

    context 'with multiple m4a attachments' do
      before do
        inbox.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/sample.m4a')),
          filename: 'first.m4a',
          content_type: 'audio/mp4'
        )
        inbox.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/sample.m4a')),
          filename: 'second.m4a',
          content_type: 'audio/x-m4a'
        )
      end

      it 'converts all m4a attachments' do
        allow_any_instance_of(described_class).to receive(:system).and_return(true)

        described_class.perform_now(inbox.id)

        inbox.reload
        expect(inbox.attachments.count).to eq(2)
        expect(inbox.attachments.map(&:content_type)).to all(eq('audio/mpeg'))
        expect(inbox.attachments.map { |a| a.filename.to_s }).to contain_exactly('first.mp3', 'second.mp3')
      end
    end

    context 'with mixed attachment types' do
      before do
        inbox.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/sample.m4a')),
          filename: 'voice.m4a',
          content_type: 'audio/mp4'
        )
        inbox.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/sample.txt')),
          filename: 'notes.txt',
          content_type: 'text/plain'
        )
      end

      it 'only converts m4a files and leaves others untouched' do
        allow_any_instance_of(described_class).to receive(:system).and_return(true)

        described_class.perform_now(inbox.id)

        inbox.reload
        expect(inbox.attachments.count).to eq(2)
        contents = inbox.attachments.map { |a| [ a.filename.to_s, a.content_type ] }
        expect(contents).to include([ 'voice.mp3', 'audio/mpeg' ])
        expect(contents).to include([ 'notes.txt', 'text/plain' ])
      end
    end

    context 'with non-m4a attachments' do
      before do
        inbox.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/sample.txt')),
          filename: 'notes.txt',
          content_type: 'text/plain'
        )
      end

      it 'does not modify any attachments' do
        expect_any_instance_of(described_class).not_to receive(:system)

        described_class.perform_now(inbox.id)

        inbox.reload
        expect(inbox.attachments.count).to eq(1)
        expect(inbox.attachments.first.filename.to_s).to eq('notes.txt')
      end

      it 'enqueues the workflow job' do
        described_class.perform_now(inbox.id)

        expect(Workflows::RunJob).to have_been_enqueued
      end
    end

    context 'with no attachments' do
      it 'does not enqueue the workflow job when no tag' do
        untagged = create(:inbox, tag: nil)

        described_class.perform_now(untagged.id)

        expect(Workflows::RunJob).not_to have_been_enqueued
      end

      it 'enqueues the workflow job when tag and workflow exist' do
        described_class.perform_now(inbox.id)

        expect(Workflows::RunJob).to have_been_enqueued
      end
    end

    context 'when inbox does not exist' do
      it 'returns without error' do
        expect {
          described_class.perform_now(0)
        }.not_to raise_error
      end
    end

    context 'when tag has no matching workflow' do
      let(:inbox_no_workflow) { create(:inbox, tag: tag) }

      before { workflow.destroy! }

      it 'does not enqueue workflow job' do
        described_class.perform_now(inbox_no_workflow.id)

        expect(Workflows::RunJob).not_to have_been_enqueued
      end
    end
  end
end
