require 'rails_helper'

RSpec.describe Workflows::RunJob, type: :job do
  let(:tag) { create(:tag, name: 'news') }
  let(:workflow) { create(:workflow, tag: tag) }
  let(:inbox) { create(:inbox, tag: tag) }

  it 'runs the workflow for the inbox' do
    runner = instance_double(Workflows::Runner, call: nil)
    allow(Workflows::Runner).to receive(:new).with(inbox).and_return(runner)

    described_class.perform_now(inbox.id)

    expect(runner).to have_received(:call)
  end

  it 'does nothing when the inbox no longer exists' do
    allow(Workflows::Runner).to receive(:new)

    described_class.perform_now(1_234_567)

    expect(Workflows::Runner).not_to have_received(:new)
  end

  it 'lets runner failures propagate for the queue to retry' do
    runner = instance_double(Workflows::Runner)
    allow(Workflows::Runner).to receive(:new).with(inbox).and_return(runner)
    allow(runner).to receive(:call).and_raise(RubyLLM::ConfigurationError, 'Missing configuration')

    expect { described_class.perform_now(inbox.id) }
      .to raise_error(RubyLLM::ConfigurationError, 'Missing configuration')
  end
end
