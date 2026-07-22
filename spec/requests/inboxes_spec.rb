require 'rails_helper'

RSpec.describe 'Inboxes', type: :request do
  let(:user) { create(:user) }
  let!(:inbox) { create(:inbox, user: user) }
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
        create(:inbox, user: user, body: 'Hidden from index')
        get inboxes_path
        expect(response.body).not_to include('Hidden from index')
      end

      it 'only lists inboxes owned by the signed-in user' do
        owned_inbox = create(:inbox, user: user, name: 'Owned inbox')
        other_inbox = create(:inbox, name: 'Other user inbox')
        legacy_inbox = create(:inbox, :unowned, name: 'Legacy inbox')

        get inboxes_path

        expect(response.body).to include(owned_inbox.name)
        expect(response.body).not_to include(other_inbox.name)
        expect(response.body).not_to include(legacy_inbox.name)
      end

      it 'includes a tag filter control' do
        tag = create(:tag, name: 'Bug')

        get inboxes_path

        expect(response.body).to include('name="tag"')
        expect(response.body).to include(tag.name)
      end

      it 'filters inboxes by tag' do
        bug = create(:tag, name: 'Bug')
        feature = create(:tag, name: 'Feature')
        tagged_inbox = create(:inbox, user: user, name: 'Tagged bug item', tag: bug)
        other_inbox = create(:inbox, user: user, name: 'Tagged feature item', tag: feature)

        get inboxes_path, params: { tag: bug.id }

        expect(response.body).to include(tagged_inbox.name)
        expect(response.body).not_to include(other_inbox.name)
      end

      it 'preserves tag filtering across status tabs' do
        tag = create(:tag, name: 'Bug')

        get inboxes_path, params: { tag: tag.id }

        expect(response.body).to include("tag=#{tag.id}")
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
        inbox_with_body = create(:inbox, user: user, body: 'Show me this')
        get inbox_path(inbox_with_body)
        expect(response.body).to include('Show me this')
      end

      it 'returns not found for another user inbox' do
        other_inbox = create(:inbox)

        get inbox_path(other_inbox)

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for an unowned legacy inbox' do
        legacy_inbox = create(:inbox, :unowned)

        get inbox_path(legacy_inbox)

        expect(response).to have_http_status(:not_found)
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
          expect(Inbox.last.user).to eq(user)
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
        it 're-renders the form with unprocessable_content status' do
          post inboxes_path, params: {
            inbox: { name: 'Bad', payload_text: '{not valid json}', metadata_text: '{}' }
          }
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('Invalid JSON')
        end
      end

      context 'with invalid JSON in metadata_text' do
        it 're-renders the form with unprocessable_content status' do
          post inboxes_path, params: {
            inbox: { name: 'Bad', payload_text: '{}', metadata_text: 'oops' }
          }
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('Invalid JSON')
        end
      end
    end

    describe 'GET /inboxes/:id/edit' do
      it 'returns 200 and pre-populates JSON fields' do
        inbox_with_data = create(:inbox, user: user, payload: { 'x' => 1 }, metadata: { 'y' => 2 })
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
        inbox_with_body = create(:inbox, user: user, body: 'Edit me')
        get edit_inbox_path(inbox_with_body)
        expect(response.body).to include('Edit me')
      end

      it 'returns not found for another user inbox' do
        other_inbox = create(:inbox)

        get edit_inbox_path(other_inbox)

        expect(response).to have_http_status(:not_found)
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
        it 're-renders the form with unprocessable_content status' do
          patch inbox_path(inbox), params: {
            inbox: { payload_text: 'bad', metadata_text: '{}' }
          }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      it 'does not update another user inbox' do
        other_inbox = create(:inbox, name: 'Other inbox')

        patch inbox_path(other_inbox), params: {
          inbox: { name: 'Changed', payload_text: '{}', metadata_text: '{}' }
        }

        expect(response).to have_http_status(:not_found)
        expect(other_inbox.reload.name).to eq('Other inbox')
      end
    end

    describe 'bulk actions' do
      it 'only archives inboxes owned by the signed-in user' do
        owned_inbox = create(:inbox, user: user, archived: false)
        other_inbox = create(:inbox, archived: false)

        patch bulk_archive_inboxes_path, params: { inbox_ids: [ owned_inbox.id, other_inbox.id ] }

        expect(owned_inbox.reload.archived).to be(true)
        expect(other_inbox.reload.archived).to be(false)
      end

      it 'only processes inboxes owned by the signed-in user' do
        workflow = create(:workflow)
        owned_inbox = create(:inbox, user: user, processed: false)
        other_inbox = create(:inbox, processed: false)

        patch bulk_process_inboxes_path, params: {
          inbox_ids: [ owned_inbox.id, other_inbox.id ],
          inbox: { workflow_id: workflow.id }
        }

        expect(owned_inbox.reload).to be_processed
        expect(owned_inbox.workflow).to eq(workflow)
        expect(other_inbox.reload).not_to be_processed
        expect(other_inbox.workflow).to be_nil
      end

      it 'only tags inboxes owned by the signed-in user' do
        tag = create(:tag)
        owned_inbox = create(:inbox, user: user, tag: nil)
        other_inbox = create(:inbox, tag: nil)

        patch bulk_tag_inboxes_path, params: {
          inbox_ids: [ owned_inbox.id, other_inbox.id ],
          inbox: { tag_id: tag.id }
        }

        expect(owned_inbox.reload.tag).to eq(tag)
        expect(other_inbox.reload.tag).to be_nil
      end

      it 'only deletes inboxes owned by the signed-in user' do
        owned_inbox = create(:inbox, user: user)
        other_inbox = create(:inbox)

        expect {
          delete bulk_destroy_inboxes_path, params: { inbox_ids: [ owned_inbox.id, other_inbox.id ] }
        }.to change(Inbox, :count).by(-1)

        expect(Inbox.exists?(owned_inbox.id)).to be(false)
        expect(Inbox.exists?(other_inbox.id)).to be(true)
      end
    end

    describe 'DELETE /inboxes/:id' do
      it 'destroys the inbox and redirects to index' do
        expect { delete inbox_path(inbox) }.to change(Inbox, :count).by(-1)
        expect(response).to redirect_to(inboxes_path)
        follow_redirect!
        expect(response.body).to include('successfully deleted')
      end

      it 'does not destroy another user inbox' do
        other_inbox = create(:inbox)

        expect { delete inbox_path(other_inbox) }.not_to change(Inbox, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
