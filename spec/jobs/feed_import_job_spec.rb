require 'rails_helper'

RSpec.describe FeedImportJob, type: :job do
  let(:feed_import) { create(:feed_import) }

  it 'stores a completed report and purges the uploaded CSV' do
    result = Feeds::ImportFromCsv::Result.new(
      imported: [ { 'row' => 2, 'title' => 'News' } ],
      unimported: [ { 'row' => 3, 'reason' => 'Feed contains no entries' } ]
    )
    importer = instance_double(Feeds::ImportFromCsv, call: result)
    allow(Feeds::ImportFromCsv).to receive(:new).and_return(importer)

    described_class.perform_now(feed_import.id)

    feed_import.reload
    expect(feed_import).to be_completed
    expect(feed_import.started_at).to be_present
    expect(feed_import.completed_at).to be_present
    expect(feed_import.imported_rows).to eq(result.imported)
    expect(feed_import.unimported_rows).to eq(result.unimported)
    expect(feed_import.csv_file).not_to be_attached
  end

  it 'stores a failed report and purges the uploaded CSV after a file-level error' do
    allow(Feeds::ImportFromCsv).to receive(:new)
      .and_raise(Feeds::ImportFromCsv::FileError, 'CSV is missing required header(s): category')

    described_class.perform_now(feed_import.id)

    feed_import.reload
    expect(feed_import).to be_failed
    expect(feed_import.error_message).to include('missing required header')
    expect(feed_import.completed_at).to be_present
    expect(feed_import.csv_file).not_to be_attached
  end

  it 'does not process an import more than once' do
    feed_import.update!(status: :completed)

    expect(Feeds::ImportFromCsv).not_to receive(:new)

    described_class.perform_now(feed_import.id)
  end
end
