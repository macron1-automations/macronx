require 'rails_helper'

RSpec.describe 'Inboxes', type: :request do
  let(:user) { create(:user) }
  let!(:inbox) { create(:inbox) }

  describe 'authentication' do
    it 'redirects unauthenticated users away from index' do
      get inboxes_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects unauthenticated users away from show' do
      get inbox_path(inbox)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'when authenticated' do
    before { sign_in user }

    describe 'GET /inboxes' do
      it 'returns 200 and renders the index' do
        get inboxes_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(inbox.name)
      end
    end

    describe 'GET /inboxes/:id' do
      it 'returns 200 and renders the inbox' do
        get inbox_path(inbox)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(inbox.name)
      end
    end

    describe 'GET /inboxes/new' do
      it 'returns 200' do
        get new_inbox_path
        expect(response).to have_http_status(:ok)
      end

      it 'pre-populates payload and metadata textareas with formatted JSON' do
        get new_inbox_path
        expect(response.body).to include('{}')
      end
    end

    describe 'POST /inboxes' do
      context 'with valid params' do
        let(:valid_params) do
          {
            inbox: {
              name: 'My Inbox',
              source: 'webhook',
              summary: 'A test entry',
              payload_text: '{"event": "created"}',
              metadata_text: '{"version": 1}'
            }
          }
        end

        it 'creates the inbox and redirects to show' do
          expect { post inboxes_path, params: valid_params }.to change(Inbox, :count).by(1)
          expect(response).to redirect_to(Inbox.last)
          follow_redirect!
          expect(response.body).to include('successfully created')
        end

        it 'stores the parsed JSON payload' do
          post inboxes_path, params: valid_params
          expect(Inbox.last.payload).to eq('event' => 'created')
        end

        it 'stores the parsed JSON metadata' do
          post inboxes_path, params: valid_params
          expect(Inbox.last.metadata).to eq('version' => 1)
        end
      end

      context 'with invalid JSON in payload_text' do
        it 're-renders the form with unprocessable_entity status' do
          post inboxes_path, params: {
            inbox: { name: 'Bad', payload_text: '{not valid json}', metadata_text: '{}' }
          }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('Invalid JSON')
        end
      end

      context 'with invalid JSON in metadata_text' do
        it 're-renders the form with unprocessable_entity status' do
          post inboxes_path, params: {
            inbox: { name: 'Bad', payload_text: '{}', metadata_text: 'oops' }
          }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('Invalid JSON')
        end
      end
    end

    describe 'GET /inboxes/:id/edit' do
      it 'returns 200 and pre-populates JSON fields' do
        inbox_with_data = create(:inbox, payload: { 'x' => 1 }, metadata: { 'y' => 2 })
        get edit_inbox_path(inbox_with_data)
        expect(response).to have_http_status(:ok)
        # Textareas HTML-escape quotes, so JSON is encoded as &quot;x&quot;: 1
        expect(CGI.unescapeHTML(response.body)).to include('"x": 1')
        expect(CGI.unescapeHTML(response.body)).to include('"y": 2')
      end
    end

    describe 'PATCH /inboxes/:id' do
      context 'with valid params' do
        it 'updates the inbox and redirects to show' do
          patch inbox_path(inbox), params: {
            inbox: {
              name: 'Updated Name',
              payload_text: '{"updated": true}',
              metadata_text: '{}'
            }
          }
          expect(response).to redirect_to(inbox)
          follow_redirect!
          expect(response.body).to include('successfully updated')
          expect(inbox.reload.name).to eq('Updated Name')
          expect(inbox.reload.payload).to eq('updated' => true)
        end
      end

      context 'with invalid JSON' do
        it 're-renders the form with unprocessable_entity status' do
          patch inbox_path(inbox), params: {
            inbox: { payload_text: 'bad', metadata_text: '{}' }
          }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe 'DELETE /inboxes/:id' do
      it 'destroys the inbox and redirects to index' do
        expect { delete inbox_path(inbox) }.to change(Inbox, :count).by(-1)
        expect(response).to redirect_to(inboxes_path)
        follow_redirect!
        expect(response.body).to include('successfully deleted')
      end
    end
  end
end
