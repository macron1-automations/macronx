require 'rails_helper'

RSpec.describe Workflows::Runner do
  let(:tag) { create(:tag, name: 'news') }
  let!(:workflow) { create(:workflow, tag: tag) }
  let(:inbox) { create(:inbox, tag: tag, payload: { 'Technology' => [ { 'feed' => 'Tech News' } ] }) }

  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:tokens) { instance_double(RubyLLM::Tokens, input: 10, output: 20) }
  let(:message) { instance_double(RubyLLM::Message, content: 'A structured digest', model_id: 'gpt-5-nano', tokens: tokens) }

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:ask).and_return(message)
  end

  describe '#call' do
    it 'updates the inbox body with the LLM response' do
      described_class.new(inbox).call

      expect(inbox.reload.body).to eq('A structured digest')
    end

    it 'marks the inbox as processed and links the workflow' do
      described_class.new(inbox).call

      expect(inbox.reload).to be_processed
      expect(inbox.reload.workflow_id).to eq(workflow.id)
    end

    it 'passes the configured prompt with the payload interpolated' do
      workflow.update!(prompt: 'Analyze this payload: {{payload}}')
      expect(chat).to receive(:ask).with("Analyze this payload: #{inbox.payload.to_json}")

      described_class.new(inbox).call
    end

    it 'leaves the prompt untouched when it has no payload placeholder' do
      workflow.update!(prompt: 'Summarize this for me.')
      expect(chat).to receive(:ask).with('Summarize this for me.')

      described_class.new(inbox).call
    end

    it 'records the model and token usage in metadata' do
      described_class.new(inbox).call

      metadata = inbox.reload.metadata
      expect(metadata['workflow_model']).to eq('gpt-5-nano')
      expect(metadata['workflow_tokens']).to eq('input' => 10, 'output' => 20)
      expect(metadata['workflow_error']).to be_nil
    end

    it 'does nothing when no workflow matches the tag' do
      workflow.destroy
      inbox.update!(tag: create(:tag))

      expect(described_class.new(inbox).call.response).to be_nil
      expect(inbox.reload).not_to be_processed
      expect(inbox.reload.body).to be_nil
    end

    context 'when the LLM call fails' do
      before do
        allow(chat).to receive(:ask).and_raise(RubyLLM::ConfigurationError, 'Missing configuration')
      end

      it 'records the error in metadata and re-raises' do
        expect { described_class.new(inbox).call }
          .to raise_error(RubyLLM::ConfigurationError, 'Missing configuration')

        expect(inbox.reload.metadata['workflow_error']).to eq('Missing configuration')
        expect(inbox.reload).not_to be_processed
        expect(inbox.reload.body).to be_nil
      end
    end
  end
end
