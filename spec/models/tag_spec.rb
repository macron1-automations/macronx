require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe 'factory' do
    it 'is valid with default attributes' do
      expect(build(:tag)).to be_valid
    end
  end

  describe 'validations' do
    it 'is invalid without a name' do
      expect(build(:tag, name: '')).not_to be_valid
    end

    it 'rejects duplicate names (case-insensitive)' do
      create(:tag, name: 'urgent')
      duplicate = build(:tag, name: 'URGENT')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it 'allows distinct names' do
      create(:tag, name: 'urgent')
      expect(build(:tag, name: 'low-priority')).to be_valid
    end
  end

  describe '#badge_classes' do
    it 'returns the stored color string when one is set' do
      tag = build(:tag, color: 'bg-blue-100 text-blue-700')
      expect(tag.badge_classes).to eq('bg-blue-100 text-blue-700')
    end

    it 'falls back to neutral gray when color is nil' do
      tag = build(:tag, color: nil)
      expect(tag.badge_classes).to eq('bg-gray-100 text-gray-700')
    end

    it 'falls back to neutral gray when color is blank' do
      tag = build(:tag, color: '')
      expect(tag.badge_classes).to eq('bg-gray-100 text-gray-700')
    end
  end

  describe 'associations' do
    it 'nullifies inbox tag_id when the tag is destroyed' do
      tag = create(:tag)
      inbox = create(:inbox, tag: tag)
      tag.destroy
      expect(inbox.reload.tag_id).to be_nil
    end

    it 'does not destroy associated inboxes when the tag is destroyed' do
      tag = create(:tag)
      create(:inbox, tag: tag)
      expect { tag.destroy }.not_to change(Inbox, :count)
    end
  end
end
