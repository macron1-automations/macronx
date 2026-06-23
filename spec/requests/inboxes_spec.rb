require 'rails_helper'

RSpec.describe 'Inboxes', type: :request do
  let(:user) { create(:user) }
  let!(:inbox) { create(:inbox) }
  let(:sample_file) { fixture_file_upload('sample.txt', 'text/plain') }
  let(:second_file) { fixture_file_upload('second.txt', 'text/plain') }

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

      it 'shows an attachment indicator when files are attached' do
        inbox.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/sample.txt')),
          filename: 'sample.txt',
          content_type: 'text/plain'
        )
        get inboxes_path
        expect(response.body).to include('Has attachments')
      end

      it 'does not display body text on the index' do
        create(:inbox, body: 'Hidden from index')
        get inboxes_path
        expect(response.body).not_to include('Hidden from index')
      end
    end

    describe 'GET /inboxes/:id' do
      it 'returns 200 and renders the inbox' do
        get inbox_path(inbox)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(inbox.name)
      end

      it 'lists attached files' do
        inbox.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/sample.txt')),
          filename: 'sample.txt',
          content_type: 'text/plain'
        )
        get inbox_path(inbox)
        expect(response.body).to include('sample.txt')
        expect(response.body).not_to include('Add attachments')
      end

      it 'displays the body text' do
        inbox_with_body = create(:inbox, body: 'Show me this')
        get inbox_path(inbox_with_body)
        expect(response.body).to include('Show me this')
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

      it 'includes a body textarea' do
        get new_inbox_path
        expect(response.body).to include('name="inbox[body]"')
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
              body: 'Created body text',
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

        it 'stores the body text' do
          post inboxes_path, params: valid_params
          expect(Inbox.last.body).to eq('Created body text')
        end

        it 'shows the body on the show page after create' do
          post inboxes_path, params: valid_params
          follow_redirect!
          expect(response.body).to include('Created body text')
        end

        it 'creates the inbox with attachments' do
          post inboxes_path, params: valid_params.deep_merge(
            inbox: { attachments: [ sample_file ] }
          )
          expect(Inbox.last.attachments).to be_attached
          expect(Inbox.last.attachments.first.filename.to_s).to eq('sample.txt')
        end

        it 'creates the inbox with multiple attachments at once' do
          post inboxes_path, params: valid_params.deep_merge(
            inbox: { attachments: [ sample_file, second_file ] }
          )
          inbox = Inbox.last
          expect(inbox.attachments.count).to eq(2)
          expect(inbox.attachments.map { |a| a.filename.to_s }).to contain_exactly('sample.txt', 'second.txt')
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

      it 'includes attachment management controls' do
        inbox.attachments.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/sample.txt')),
          filename: 'sample.txt',
          content_type: 'text/plain'
        )
        get edit_inbox_path(inbox)
        expect(response.body).to include('Add attachments')
        expect(response.body).to include('sample.txt')
        expect(response.body).to include('permanently removed on save')
      end

      it 'pre-populates the body textarea' do
        inbox_with_body = create(:inbox, body: 'Edit me')
        get edit_inbox_path(inbox_with_body)
        expect(response.body).to include('Edit me')
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

        it 'updates the body text' do
          patch inbox_path(inbox), params: {
            inbox: {
              name: inbox.name,
              body: 'Updated body',
              payload_text: '{}',
              metadata_text: '{}'
            }
          }
          expect(response).to redirect_to(inbox)
          expect(inbox.reload.body).to eq('Updated body')
          follow_redirect!
          expect(response.body).to include('Updated body')
        end

        it 'updates the body via multipart form submission' do
          patch inbox_path(inbox), params: {
            inbox: {
              name: inbox.name,
              source: inbox.source,
              summary: inbox.summary,
              body: 'Multipart body update',
              tag_id: '',
              payload_text: '{}',
              metadata_text: '{}',
              attachments: [ sample_file ]
            }
          }
          expect(response).to redirect_to(inbox)
          expect(inbox.reload.body).to eq('Multipart body update')
        end

        it 'purges selected attachments' do
          inbox.attachments.attach(
            io: File.open(Rails.root.join('spec/fixtures/files/sample.txt')),
            filename: 'sample.txt',
            content_type: 'text/plain'
          )
          signed_id = inbox.attachments.first.blob.signed_id

          patch inbox_path(inbox), params: {
            inbox: {
              name: inbox.name,
              payload_text: '{}',
              metadata_text: '{}',
              purge_attachment_signed_ids: [ signed_id ]
            }
          }

          expect(response).to redirect_to(inbox)
          expect(inbox.reload.attachments).not_to be_attached
        end

        it 'appends attachments without removing existing ones' do
          inbox.attachments.attach(
            io: StringIO.new('first'),
            filename: 'first.txt',
            content_type: 'text/plain'
          )

          patch inbox_path(inbox), params: {
            inbox: {
              attachments: [ fixture_file_upload('sample.txt', 'text/plain') ]
            }
          }

          expect(response).to redirect_to(inbox)
          inbox.reload
          expect(inbox.attachments.count).to eq(2)
          expect(inbox.attachments.map { |a| a.filename.to_s }).to contain_exactly('first.txt', 'sample.txt')
        end

        it 'uploads multiple attachments at once' do
          patch inbox_path(inbox), params: {
            inbox: {
              name: inbox.name,
              payload_text: '{}',
              metadata_text: '{}',
              attachments: [ sample_file, second_file ]
            }
          }

          expect(response).to redirect_to(inbox)
          inbox.reload
          expect(inbox.attachments.count).to eq(2)
          expect(inbox.attachments.map { |a| a.filename.to_s }).to contain_exactly('sample.txt', 'second.txt')
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
