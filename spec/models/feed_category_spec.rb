require 'rails_helper'

RSpec.describe FeedCategory, type: :model do
  describe 'factory' do
    it 'is valid with default attributes' do
      expect(build(:feed_category)).to be_valid
    end
  end

  describe 'validations' do
    it 'is invalid without a name' do
      expect(build(:feed_category, name: '')).not_to be_valid
    end

    it 'rejects duplicate names case-insensitively' do
      create(:feed_category, name: 'Technology')
      duplicate = build(:feed_category, name: 'TECHNOLOGY')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it 'allows distinct names' do
      create(:feed_category, name: 'Technology')

      expect(build(:feed_category, name: 'Science')).to be_valid
    end
  end

  describe 'associations' do
    it 'allows multiple feeds to share a category' do
      category = create(:feed_category)
      feeds = create_list(:feed, 2, feed_category: category)

      expect(category.reload.feeds).to contain_exactly(*feeds)
    end

    it 'cannot be destroyed while feeds remain assigned' do
      category = create(:feed_category)
      feed = create(:feed, feed_category: category)

      expect(category.destroy).to be false
      expect(category.errors[:base]).to be_present
      expect(described_class.exists?(category.id)).to be true
      expect(Feed.exists?(feed.id)).to be true
    end
  end
end
