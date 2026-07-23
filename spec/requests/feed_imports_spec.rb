require 'rails_helper'

RSpec.describe 'Feed Imports', type: :request do
  let(:user) { create(:user) }
  let(:csv_file) { fixture_file_upload('feeds.csv', 'text/csv') }

  describe 'authentication' do
    it 'redirects unauthenticated users away from the upload form' do
      get new_feed_import_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects unauthenticated users away from reports' do
      feed_import = create(:feed_import)

      get feed_import_path(feed_import)

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'when authenticated' do
    before { sign_in user }

    it 'renders the CSV upload form' do
      get new_feed_import_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="feed_import[csv_file]"', 'title', 'category', 'feed_url')
    end

    it 'creates a user-owned import and enqueues its job' do
      expect {
        post feed_imports_path, params: { feed_import: { csv_file: csv_file } }
      }.to have_enqueued_job(FeedImportJob).and change(FeedImport, :count).by(1)

      feed_import = FeedImport.last
      expect(feed_import.user).to eq(user)
      expect(feed_import.source_filename).to eq('feeds.csv')
      expect(response).to redirect_to(feed_import)
    end

    it 'rejects an upload without a file' do
      expect {
        post feed_imports_path, params: { feed_import: {} }
      }.not_to change(FeedImport, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Csv file is required')
    end

    it 'rejects an upload that is not named as a CSV file' do
      text_file = fixture_file_upload('sample.txt', 'text/plain')

      expect {
        post feed_imports_path, params: { feed_import: { csv_file: text_file } }
      }.not_to change(FeedImport, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Csv file must be a CSV file')
    end

    it 'does not expose another user report' do
      other_import = create(:feed_import)

      get feed_import_path(other_import)

      expect(response).to have_http_status(:not_found)
    end

    it 'auto-refreshes a pending report' do
      feed_import = create(:feed_import, user: user)

      get feed_import_path(feed_import)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('http-equiv="refresh"', 'Validating and importing feeds')
    end

    it 'shows imported and unimported rows in a completed report' do
      feed_import = create(
        :feed_import,
        user: user,
        status: :completed,
        imported_rows: [
          { 'row' => 2, 'title' => 'Imported News', 'category' => 'Research', 'feed_url' => 'https://example.com/good.xml', 'category_status' => 'created' }
        ],
        unimported_rows: [
          { 'row' => 3, 'title' => 'Empty News', 'category' => 'Research', 'feed_url' => 'https://example.com/empty.xml', 'reason' => 'Feed contains no entries' }
        ]
      )

      get feed_import_path(feed_import)

      expect(response.body).to include('Imported News', 'Empty News', 'Feed contains no entries')
      expect(response.body).to match(%r{Imported</p>\s*<p[^>]*>1</p>})
      expect(response.body).to match(%r{Unimported</p>\s*<p[^>]*>1</p>})
    end

    it 'shows a file-level failure' do
      feed_import = create(:feed_import, user: user, status: :failed, error_message: 'CSV is malformed')

      get feed_import_path(feed_import)

      expect(response.body).to include('Import failed', 'CSV is malformed')
    end
  end
end
