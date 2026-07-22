require 'rails_helper'

RSpec.describe Feed, type: :model do
  describe 'factory' do
    it 'is valid with default attributes' do
      expect(build(:feed)).to be_valid
    end
  end

  describe 'validations' do
    it 'is invalid without a title' do
      expect(build(:feed, title: '')).not_to be_valid
    end

    it 'is invalid without a feed URL' do
      expect(build(:feed, feed_url: '')).not_to be_valid
    end

    it 'is invalid without a feed category' do
      expect(build(:feed, feed_category: nil)).not_to be_valid
    end

    it 'rejects duplicate feed URLs' do
      create(:feed, feed_url: 'https://example.com/feed.xml')
      duplicate = build(:feed, feed_url: 'https://example.com/feed.xml')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:feed_url]).to be_present
    end

    it 'allows distinct feed URLs' do
      create(:feed, feed_url: 'https://example.com/first.xml')

      expect(build(:feed, feed_url: 'https://example.com/second.xml')).to be_valid
    end
  end
end
