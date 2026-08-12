require 'rails_helper'

RSpec.describe Workflows::Reprocessor do
  let(:news_tag) { create(:tag, name: 'news') }
  let!(:workflow) { create(:workflow, tag: news_tag) }

  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:tokens) { instance_double(RubyLLM::Tokens, input: 10, output: 20) }
  let(:message) { instance_double(RubyLLM::Message, content: 'A fresh digest', model_id: 'gpt-5-nano', tokens: tokens) }

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:ask).and_return(message)
  end

  def processed_inbox(created_at:)
    create(:inbox, tag: news_tag, workflow: workflow, processed: true, body: 'stale body', created_at: created_at)
  end

  describe '#call' do
    it 're-processes the most recent items, newest first' do
      older = processed_inbox(created_at: 3.days.ago)
      middle = processed_inbox(created_at: 2.days.ago)
      newest = processed_inbox(created_at: 1.day.ago)

      result = described_class.new(tag_name: 'news', limit: 3).call

      expect(result.count).to eq(3)
      expect(result.reprocessed).to eq([ newest, middle, older ])
      expect(result.errors).to be_empty
    end

    it 'limits the number of items processed' do
      3.times { processed_inbox(created_at: 1.day.ago) }

      result = described_class.new(tag_name: 'news', limit: 2).call

      expect(result.count).to eq(2)
      expect(result.reprocessed.size).to eq(2)
    end

    it 'updates the body of each item' do
      inbox = processed_inbox(created_at: 1.day.ago)

      described_class.new(tag_name: 'news', limit: 1).call

      expect(inbox.reload.body).to eq('A fresh digest')
    end

    it 'excludes unprocessed and archived items' do
      processed_inbox(created_at: 1.day.ago)
      create(:inbox, tag: news_tag, created_at: 2.days.ago)
      create(:inbox, tag: news_tag, workflow: workflow, processed: true, archived: true, created_at: 3.days.ago)

      result = described_class.new(tag_name: 'news', limit: 10).call

      expect(result.count).to eq(1)
    end

    it 'returns an empty result when the tag does not exist' do
      result = described_class.new(tag_name: 'nope', limit: 5).call

      expect(result.count).to eq(0)
      expect(result.reprocessed).to be_empty
      expect(result.skipped).to be_empty
      expect(result.errors).to be_empty
    end

    it 'skips items whose tag has no workflow' do
      other_tag = create(:tag, name: 'no-workflow')
      tagless = create(:inbox, tag: other_tag, workflow: workflow, processed: true, created_at: 1.day.ago)

      result = described_class.new(tag_name: 'no-workflow', limit: 5).call

      expect(result.skipped).to eq([ tagless ])
      expect(result.reprocessed).to be_empty
    end

    it 'records errors per item and keeps processing the rest' do
      failed = processed_inbox(created_at: 1.day.ago)
      succeeded = processed_inbox(created_at: 2.days.ago)

      calls = 0
      allow(chat).to receive(:ask) do
        calls += 1
        raise RubyLLM::ConfigurationError, 'Missing configuration' if calls == 1

        message
      end

      result = described_class.new(tag_name: 'news', limit: 5).call

      expect(result.reprocessed).to eq([ succeeded ])
      expect(result.errors).to eq([ { inbox_id: failed.id, error: 'Missing configuration' } ])
      expect(failed.reload.metadata['workflow_error']).to eq('Missing configuration')
    end
  end
end
