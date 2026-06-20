require 'rails_helper'

RSpec.describe Inbox, type: :model do
  describe 'factory' do
    it 'is valid with default attributes' do
      expect(build(:inbox)).to be_valid
    end
  end

  describe 'JSON virtual attributes' do
    describe '#payload_text=' do
      it 'parses valid JSON into the payload column on validation' do
        inbox = build(:inbox, payload_text: '{"foo": "bar"}')
        inbox.valid?
        expect(inbox.payload).to eq('foo' => 'bar')
      end

      it 'parses nested JSON correctly' do
        inbox = build(:inbox, payload_text: '{"nested": {"a": 1}}')
        inbox.valid?
        expect(inbox.payload).to eq('nested' => { 'a' => 1 })
      end

      it 'adds an error and halts when payload_text is invalid JSON' do
        inbox = build(:inbox, payload_text: 'not json')
        expect(inbox).not_to be_valid
        expect(inbox.errors[:base].first).to match(/Invalid JSON/)
      end

      it 'leaves payload unchanged when payload_text is blank' do
        inbox = build(:inbox, payload: { 'existing' => true }, payload_text: '')
        inbox.valid?
        expect(inbox.payload).to eq('existing' => true)
      end
    end

    describe '#metadata_text=' do
      it 'parses valid JSON into the metadata column on validation' do
        inbox = build(:inbox, metadata_text: '{"source": "api"}')
        inbox.valid?
        expect(inbox.metadata).to eq('source' => 'api')
      end

      it 'adds an error and halts when metadata_text is invalid JSON' do
        inbox = build(:inbox, metadata_text: '{bad json}')
        expect(inbox).not_to be_valid
        expect(inbox.errors[:base].first).to match(/Invalid JSON/)
      end

      it 'leaves metadata unchanged when metadata_text is blank' do
        inbox = build(:inbox, metadata: { 'version' => 2 }, metadata_text: '')
        inbox.valid?
        expect(inbox.metadata).to eq('version' => 2)
      end
    end

    it 'parses both fields in one pass without conflict' do
      inbox = build(:inbox,
                    payload_text: '{"p": 1}',
                    metadata_text: '{"m": 2}')
      inbox.valid?
      expect(inbox.payload).to eq('p' => 1)
      expect(inbox.metadata).to eq('m' => 2)
    end
  end

  describe 'tag association' do
    it 'is valid without a tag (optional)' do
      expect(build(:inbox, tag: nil)).to be_valid
    end

    it 'is valid when a tag is assigned' do
      tag = create(:tag)
      expect(build(:inbox, tag: tag)).to be_valid
    end

    it 'exposes the tag name via the association' do
      tag = create(:tag, name: 'urgent')
      inbox = create(:inbox, tag: tag)
      expect(inbox.reload.tag.name).to eq('urgent')
    end

    it 'can have its tag cleared' do
      tag = create(:tag)
      inbox = create(:inbox, tag: tag)
      inbox.update!(tag: nil)
      expect(inbox.reload.tag).to be_nil
    end
  end

  describe 'persistence' do
    it 'saves and reloads jsonb fields correctly' do
      inbox = create(:inbox, payload: { 'key' => 'value' }, metadata: { 'env' => 'test' })
      inbox.reload
      expect(inbox.payload).to eq('key' => 'value')
      expect(inbox.metadata).to eq('env' => 'test')
    end

    it 'defaults payload and metadata to empty hashes' do
      inbox = create(:inbox)
      inbox.reload
      expect(inbox.payload).to eq({})
      expect(inbox.metadata).to eq({})
    end
  end
end
