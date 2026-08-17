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

    describe 'summary generation' do
      it 'writes a short summary from a second LLM call' do
        described_class.new(inbox).call

        expect(inbox.reload.summary).to eq('A structured digest')
      end

      it 'uses the default summary prompt with the body interpolated' do
        expected = Workflows::Runner::DEFAULT_SUMMARY_PROMPT.gsub('{{body}}', 'A structured digest')
        expect(chat).to receive(:ask).with(expected).and_return(message)

        described_class.new(inbox).call
      end

      it 'uses the workflow’s configured summary prompt' do
        workflow.update!(summary_prompt: "Condense this for me:\n\n{{body}}")
        expect(chat).to receive(:ask).with("Condense this for me:\n\nA structured digest").and_return(message)

        described_class.new(inbox).call
      end

      it 'appends the body when the configured summary prompt has no {{body}} placeholder' do
        workflow.update!(summary_prompt: 'Condense this for me:')
        expect(chat).to receive(:ask).with("Condense this for me:\n\nA structured digest").and_return(message)

        described_class.new(inbox).call
      end

      it 'clears summary_error in metadata on success' do
        inbox.update!(metadata: { 'summary_error' => 'previous failure' })

        described_class.new(inbox).call

        expect(inbox.reload.metadata['summary_error']).to be_nil
      end

      it 'keeps the body and records an error when summary generation fails' do
        calls = 0
        allow(chat).to receive(:ask) do
          calls += 1
          raise RubyLLM::ConfigurationError, 'Summary failed' if calls == 2

          message
        end

        expect { described_class.new(inbox).call }.not_to raise_error

        inbox.reload
        expect(inbox.body).to eq('A structured digest')
        expect(inbox).to be_processed
        expect(inbox.metadata['summary_error']).to eq('Summary failed')
        expect(inbox.summary).to eq('A test inbox summary')
      end
    end

    context 'with include_attachments enabled' do
      before { workflow.update!(include_attachments: true) }

      it 'passes attachments to the LLM when present' do
        file = fixture_file_upload('spec/fixtures/files/sample.txt', 'text/plain')
        inbox.attachments.attach(file)

        expect(chat).to receive(:ask).with(
          instance_of(String),
          with: instance_of(ActiveStorage::Attached::Many)
        ).and_return(message)

        described_class.new(inbox).call
      end

      it 'does not pass with: when inbox has no attachments' do
        expect(chat).to receive(:ask).with(instance_of(String)).and_return(message)

        described_class.new(inbox).call
      end
    end

    context 'with include_attachments disabled' do
      it 'does not pass attachments even when present' do
        workflow.update!(include_attachments: false)
        file = fixture_file_upload('spec/fixtures/files/sample.txt', 'text/plain')
        inbox.attachments.attach(file)

        expect(chat).to receive(:ask).with(instance_of(String)).and_return(message)

        described_class.new(inbox).call
      end
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
