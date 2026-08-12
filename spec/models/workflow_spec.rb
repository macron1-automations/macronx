require 'rails_helper'

RSpec.describe Workflow, type: :model do
  describe 'factory' do
    it 'is valid with default attributes' do
      expect(build(:workflow)).to be_valid
    end
  end

  describe 'validations' do
    it 'requires a name' do
      expect(build(:workflow, name: nil)).not_to be_valid
    end

    it 'requires a prompt' do
      expect(build(:workflow, prompt: nil)).not_to be_valid
    end

    it 'is valid without a tag (optional)' do
      expect(build(:workflow, tag: nil)).to be_valid
    end
  end

  describe 'tag association' do
    it 'allows only one workflow per tag' do
      tag = create(:tag)
      create(:workflow, tag: tag)

      expect(build(:workflow, tag: tag)).not_to be_valid
    end

    it 'allows the same tag to be reused after the workflow is deleted' do
      tag = create(:tag)
      create(:workflow, tag: tag).destroy

      expect(build(:workflow, tag: tag)).to be_valid
    end

    it 'exposes the tag via the association' do
      tag = create(:tag, name: 'news')
      workflow = create(:workflow, tag: tag)

      expect(workflow.reload.tag.name).to eq('news')
    end
  end

  describe 'inboxes association' do
    it 'returns items processed by the workflow' do
      workflow = create(:workflow)
      inbox = create(:inbox, workflow: workflow)

      expect(workflow.inboxes).to include(inbox)
    end
  end
end
