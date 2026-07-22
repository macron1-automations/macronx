require 'rails_helper'

RSpec.describe 'Feeds', type: :request do
  let(:user) { create(:user) }
  let(:feed_category) { create(:feed_category, name: 'Technology') }
  let!(:feed) { create(:feed, title: 'Tech News', feed_url: 'https://example.com/tech.xml', feed_category: feed_category) }

  describe 'authentication' do
    it 'redirects unauthenticated users away from index' do
      get feeds_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects unauthenticated users away from show' do
      get feed_path(feed)

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'when authenticated' do
    before { sign_in user }

    describe 'GET /feeds' do
      it 'lists feeds with their categories and sidebar links' do
        get feeds_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(feed.title, feed.feed_url, feed_category.name)
        expect(response.body).to include('href="/feeds"', 'href="/feed_categories"')
      end

      it 'eager loads feed categories' do
        expect(Feed).to receive(:includes).with(:feed_category).and_call_original

        get feeds_path
      end
    end

    describe 'GET /feeds/:id' do
      it 'shows the feed details' do
        get feed_path(feed)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(feed.title, feed.feed_url, feed_category.name)
      end
    end

    describe 'GET /feeds/new' do
      it 'shows categories ordered by name' do
        create(:feed_category, name: 'Business')

        get new_feed_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('name="feed[feed_category_id]"')
        expect(response.body.index('Business')).to be < response.body.index('Technology')
      end
    end

    describe 'POST /feeds' do
      it 'creates a feed and redirects to show' do
        expect {
          post feeds_path, params: {
            feed: {
              title: 'Business News',
              feed_url: 'https://example.com/business.xml',
              feed_category_id: feed_category.id
            }
          }
        }.to change(Feed, :count).by(1)

        created_feed = Feed.order(:created_at).last
        expect(response).to redirect_to(created_feed)
        expect(created_feed.feed_category).to eq(feed_category)
        follow_redirect!
        expect(response.body).to include('successfully created')
      end

      it 're-renders the form for invalid attributes' do
        expect {
          post feeds_path, params: { feed: { title: '', feed_url: '', feed_category_id: '' } }
        }.not_to change(Feed, :count)

        expect(response).to have_http_status(:unprocessable_content)
        rendered_body = CGI.unescapeHTML(response.body)
        expect(rendered_body).to include("Title can't be blank", "Feed url can't be blank")
      end
    end

    describe 'GET /feeds/:id/edit' do
      it 'shows the edit form with the current category selected' do
        get edit_feed_path(feed)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(feed.title, feed.feed_url, 'selected="selected"')
      end
    end

    describe 'PATCH /feeds/:id' do
      it 'updates the feed and redirects to show' do
        new_category = create(:feed_category, name: 'Science')

        patch feed_path(feed), params: {
          feed: {
            title: 'Science News',
            feed_url: 'https://example.com/science.xml',
            feed_category_id: new_category.id
          }
        }

        expect(response).to redirect_to(feed)
        expect(feed.reload).to have_attributes(
          title: 'Science News',
          feed_url: 'https://example.com/science.xml',
          feed_category: new_category
        )
      end

      it 're-renders the form for invalid attributes' do
        patch feed_path(feed), params: { feed: { title: '' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(CGI.unescapeHTML(response.body)).to include("Title can't be blank")
      end
    end

    describe 'DELETE /feeds/:id' do
      it 'deletes the feed and redirects to index' do
        expect { delete feed_path(feed) }.to change(Feed, :count).by(-1)

        expect(response).to redirect_to(feeds_path)
        follow_redirect!
        expect(response.body).to include('successfully deleted')
      end
    end
  end
end
