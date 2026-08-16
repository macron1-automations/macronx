require 'rails_helper'

RSpec.describe 'Tags', type: :request do
  let(:user) { create(:user) }
  let!(:tag) { create(:tag, name: 'Important', color: 'bg-red-100 text-red-700') }

  describe 'authentication' do
    it 'redirects unauthenticated users away from index' do
      get tags_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects unauthenticated users away from show' do
      get tag_path(tag)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'when authenticated' do
    before { sign_in user }

    describe 'GET /tags' do
      it 'returns 200 and renders the index' do
        get tags_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(tag.name)
      end

      it 'shows a per-user inbox count for each tag' do
        create(:inbox, user: user, tag: tag)
        other_tag = create(:tag, name: 'Other')
        other_tagged = create(:inbox, user: user, tag: other_tag)

        get tags_path

        expect(response.body).to include('1')
        expect(other_tagged.reload.tag).to eq(other_tag)
      end
    end

    describe 'GET /tags/:id' do
      it 'returns 200 and renders the tag' do
        get tag_path(tag)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(tag.name)
        expect(response.body).to include('bg-red-100 text-red-700')
      end

      it 'lists inbox items with the tag owned by the signed-in user' do
        owned_inbox = create(:inbox, user: user, name: 'My tagged item', tag: tag)
        other_inbox = create(:inbox, name: 'Other user item', tag: tag)

        get tag_path(tag)

        expect(response.body).to include(owned_inbox.name)
        expect(response.body).not_to include(other_inbox.name)
      end

      it 'lists workflows triggered by the tag' do
        workflow = create(:workflow, name: 'News Workflow', tag: tag)

        get tag_path(tag)

        expect(response.body).to include(workflow.name)
      end
    end

    describe 'GET /tags/new' do
      it 'returns 200' do
        get new_tag_path
        expect(response).to have_http_status(:ok)
      end

      it 'includes a name field' do
        get new_tag_path
        expect(response.body).to include('name="tag[name]"')
      end
    end

    describe 'POST /tags' do
      context 'with valid params' do
        it 'creates the tag and redirects to show' do
          expect {
            post tags_path, params: { tag: { name: 'Urgent', color: 'bg-amber-100 text-amber-800' } }
          }.to change(Tag, :count).by(1)
          expect(response).to redirect_to(Tag.last)
          follow_redirect!
          expect(response.body).to include('successfully created')
        end

        it 'stores the selected color' do
          post tags_path, params: { tag: { name: 'Urgent', color: 'bg-amber-100 text-amber-800' } }
          expect(Tag.last.color).to eq('bg-amber-100 text-amber-800')
        end

        it 'defaults color to empty when none is selected' do
          post tags_path, params: { tag: { name: 'Urgent', color: '' } }
          expect(Tag.last.color).to eq('')
        end
      end

      context 'with invalid params' do
        it 're-renders the form with unprocessable_content status when name is blank' do
          post tags_path, params: { tag: { name: '' } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('error')
        end

        it 're-renders the form when the name is a duplicate' do
          expect {
            post tags_path, params: { tag: { name: tag.name } }
          }.not_to change(Tag, :count)
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe 'GET /tags/:id/edit' do
      it 'returns 200 and pre-populates the name and color' do
        get edit_tag_path(tag)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(tag.name)
        expect(response.body).to include('bg-red-100 text-red-700')
      end
    end

    describe 'PATCH /tags/:id' do
      context 'with valid params' do
        it 'updates the tag and redirects to show' do
          patch tag_path(tag), params: { tag: { name: 'Renamed', color: 'bg-blue-100 text-blue-700' } }
          expect(response).to redirect_to(tag)
          follow_redirect!
          expect(response.body).to include('successfully updated')
          expect(tag.reload.name).to eq('Renamed')
          expect(tag.reload.color).to eq('bg-blue-100 text-blue-700')
        end
      end

      context 'with invalid params' do
        it 're-renders the form with unprocessable_content status' do
          patch tag_path(tag), params: { tag: { name: '' } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(tag.reload.name).to eq('Important')
        end
      end
    end

    describe 'DELETE /tags/:id' do
      it 'destroys the tag and redirects to index' do
        expect { delete tag_path(tag) }.to change(Tag, :count).by(-1)
        expect(response).to redirect_to(tags_path)
        follow_redirect!
        expect(response.body).to include('successfully deleted')
      end

      it 'nullifies associated inboxes' do
        inbox = create(:inbox, user: user, tag: tag)

        delete tag_path(tag)

        expect(inbox.reload.tag_id).to be_nil
      end

      it 'nullifies associated workflows' do
        workflow = create(:workflow, tag: tag)

        expect { delete tag_path(tag) }.not_to change(Workflow, :count)

        expect(workflow.reload.tag_id).to be_nil
      end
    end
  end
end
