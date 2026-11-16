require 'rails_helper'

RSpec.describe 'Root path', type: :request do
  describe 'GET /' do
    it 'redirects to /inboxes' do
      get root_path
      expect(response).to redirect_to('/inboxes')
    end

    context 'when unauthenticated' do
      it 'redirects to sign-in upon following redirect to /inboxes' do
        get root_path
        follow_redirect!
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated' do
      let(:user) { create(:user) }

      before { sign_in user }

      it 'lands on /inboxes successfully when following redirect' do
        get root_path
        follow_redirect!
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
