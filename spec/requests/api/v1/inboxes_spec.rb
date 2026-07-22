require 'rails_helper'

RSpec.describe 'Api::V1::Inboxes', type: :request do
  let(:user) { create(:user) }
  let(:token) { user.api_token }
  let(:auth_headers) { { 'Authorization' => "Bearer #{token}" } }
  let(:other_user) { create(:user) }
  let(:sample_file) { fixture_file_upload('sample.txt', 'text/plain') }
  let(:second_file) { fixture_file_upload('second.txt', 'text/plain') }

  describe 'POST /api/v1/inboxes' do
    it 'creates an inbox with attachments via multipart upload' do
      post api_v1_inboxes_path, params: {
        inbox: {
          source: 'api',
          summary: 'With attachment',
          payload: { event: 'created' },
          metadata: { version: 1 },
          attachments: [ sample_file ]
        }
      }, headers: auth_headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['attachments'].size).to eq(1)
      expect(body['attachments'].first['filename']).to eq('sample.txt')
      expect(body['attachments'].first['url']).to include('/rails/active_storage/blobs/')
      expect(Inbox.last.attachments).to be_attached
      expect(Inbox.last.user).to eq(user)
    end

    it 'creates an inbox with multiple attachments at once' do
      post api_v1_inboxes_path, params: {
        inbox: {
          source: 'api',
          summary: 'With attachments',
          payload: { event: 'created' },
          metadata: { version: 1 },
          attachments: [ sample_file, second_file ]
        }
      }, headers: auth_headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['attachments'].size).to eq(2)
      expect(body['attachments'].map { |a| a['filename'] }).to contain_exactly('sample.txt', 'second.txt')
    end

    it 'creates an inbox with a custom name' do
      post api_v1_inboxes_path, params: {
        inbox: {
          name: 'My custom inbox',
          source: 'api',
          summary: 'Named item'
        }
      }, headers: auth_headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['name']).to eq('My custom inbox')
      expect(Inbox.last.name).to eq('My custom inbox')
    end

    it 'auto-generates a name when none is provided' do
      post api_v1_inboxes_path, params: {
        inbox: { source: 'api', summary: 'Unnamed item' }
      }, headers: auth_headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['name']).to match(/\Ainbox-[0-9a-f]{8}\z/)
    end

    it 'creates an inbox with a body' do
      post api_v1_inboxes_path, params: {
        inbox: {
          source: 'api',
          summary: 'With body',
          body: 'API body content',
          payload: { event: 'created' },
          metadata: { version: 1 }
        }
      }, headers: auth_headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['body']).to eq('API body content')
      expect(Inbox.last.body).to eq('API body content')
    end

    it 'returns unauthorized without a token' do
      post api_v1_inboxes_path, params: { inbox: { source: 'api' } }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/inboxes/:id' do
    let!(:inbox) { create(:inbox, user: user, source: 'api', summary: 'Test', body: 'Fetched body') }

    before do
      inbox.attachments.attach(
        io: File.open(Rails.root.join('spec/fixtures/files/sample.txt')),
        filename: 'sample.txt',
        content_type: 'text/plain'
      )
    end

    it 'returns attachment metadata and download URL' do
      get api_v1_inbox_path(inbox), headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['attachments'].size).to eq(1)
      expect(body['attachments'].first).to include(
        'filename' => 'sample.txt',
        'content_type' => 'text/plain'
      )
      expect(body['attachments'].first['url']).to include('/rails/active_storage/blobs/')
      expect(body['body']).to eq('Fetched body')
    end

    it 'returns not found for another user inbox' do
      other_inbox = create(:inbox, user: other_user, source: 'api')

      get api_v1_inbox_path(other_inbox), headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for an unowned legacy inbox' do
      legacy_inbox = create(:inbox, :unowned, source: 'api')

      get api_v1_inbox_path(legacy_inbox), headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/inboxes' do
    it 'includes body in list responses for the token owner only' do
      owned_inbox = create(:inbox, user: user, source: 'api', body: 'Listed body')
      create(:inbox, user: user, source: 'api', body: nil)
      other_inbox = create(:inbox, user: other_user, source: 'api', body: 'Other user body')
      legacy_inbox = create(:inbox, :unowned, source: 'api', body: 'Legacy body')

      get api_v1_inboxes_path, headers: auth_headers

      expect(response).to have_http_status(:ok)
      bodies = JSON.parse(response.body)
      expect(bodies).to all(have_key('body'))
      expect(bodies.find { |i| i['body'] == 'Listed body' }).to be_present
      expect(bodies.map { |i| i['id'] }).to include(owned_inbox.id)
      expect(bodies.map { |i| i['id'] }).not_to include(other_inbox.id, legacy_inbox.id)
    end
  end
end
