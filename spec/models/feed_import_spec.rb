require 'rails_helper'

RSpec.describe FeedImport, type: :model do
  it 'is valid with the factory defaults' do
    expect(build(:feed_import)).to be_valid
  end

  it 'requires a CSV attachment while pending' do
    feed_import = build(:feed_import)
    feed_import.csv_file.detach

    expect(feed_import).not_to be_valid
    expect(feed_import.errors[:csv_file]).to include('is required')
  end

  it 'rejects a non-CSV filename' do
    feed_import = build(:feed_import)
    feed_import.csv_file.attach(io: StringIO.new('data'), filename: 'feeds.txt', content_type: 'text/plain')

    expect(feed_import).not_to be_valid
    expect(feed_import.errors[:csv_file]).to include('must be a CSV file')
  end

  it 'rejects CSV files larger than one megabyte' do
    feed_import = build(:feed_import)
    feed_import.csv_file.attach(
      io: StringIO.new('x' * (described_class::MAX_FILE_SIZE + 1)),
      filename: 'feeds.csv',
      content_type: 'text/csv'
    )

    expect(feed_import).not_to be_valid
    expect(feed_import.errors[:csv_file]).to include('must be 1 MB or smaller')
  end

  it 'allows completed reports to remain valid after the attachment is purged' do
    feed_import = create(:feed_import, status: :completed)
    feed_import.csv_file.purge

    expect(feed_import.reload).to be_valid
  end

  it 'reports imported and unimported counts' do
    feed_import = build(:feed_import, imported_rows: [ { 'row' => 2 } ], unimported_rows: [ { 'row' => 3 }, { 'row' => 4 } ])

    expect(feed_import.imported_count).to eq(1)
    expect(feed_import.unimported_count).to eq(2)
  end
end
