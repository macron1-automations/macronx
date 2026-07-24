require 'rails_helper'

RSpec.describe 'Feed Categories', type: :request do
  let(:user) { create(:user) }
  let!(:feed_category) { create(:feed_category, name: 'Technology') }

  describe 'authentication' do
    it 'redirects unauthenticated users away from index' do
      get feed_categories_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects unauthenticated users away from show' do
      get feed_category_path(feed_category)

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'when authenticated' do
    before { sign_in user }

    describe 'GET /feed_categories' do
      it 'lists categories and their feed counts' do
        create_list(:feed, 2, feed_category: feed_category)

        get feed_categories_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(feed_category.name)
        expect(response.body).to match(%r{>\s*2\s*</span>})
      end

      it 'shows feed navigation and category list shortcuts' do
        get feed_categories_path

        expect(response.body).to include('data-controller="keyboard-shortcuts"')
        expect(response.body).to include('href="/feeds"', 'Back to Feeds (u)')
        expect(response.body).to include('href="/feed_categories/new"', 'New Feed Category (n)')
        expect(response.body).to include('data-keyboard-shortcuts-key="u"', 'data-keyboard-shortcuts-key="n"')
        expect(response.body).to include('Keyboard Shortcuts', 'Category list')
      end

      it 'orders categories by name' do
        create(:feed_category, name: 'Business')

        get feed_categories_path

        expect(response.body.index('Business')).to be < response.body.index('Technology')
      end
    end

    describe 'GET /feed_categories/:id' do
      it 'shows associated feeds ordered by title' do
        later_feed = create(:feed, title: 'Zebra Feed', feed_category: feed_category)
        earlier_feed = create(:feed, title: 'Alpha Feed', feed_category: feed_category)

        get feed_category_path(feed_category)

        expect(response).to have_http_status(:ok)
        expect(response.body.index(earlier_feed.title)).to be < response.body.index(later_feed.title)
      end

      it 'shows category view shortcuts and preserves delete confirmation' do
        get feed_category_path(feed_category)

        expect(response.body).to include('data-controller="keyboard-shortcuts"')
        expect(response.body).to include('Back to Feed Categories (u)', 'Edit category (e)', 'Delete category (d)')
        expect(response.body).to include(
          'data-keyboard-shortcuts-key="u"',
          'data-keyboard-shortcuts-key="e"',
          'data-keyboard-shortcuts-key="d"'
        )
        expect(response.body).to include("Delete &quot;#{feed_category.name}&quot;? This cannot be undone.")
        expect(response.body).to include('Keyboard Shortcuts', 'Category view')
      end
    end

    describe 'GET /feed_categories/new' do
      it 'renders the new category form' do
        get new_feed_category_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('name="feed_category[name]"')
        expect(response.body).to include('data-controller="keyboard-shortcuts"')
        expect(response.body).to include('Back to Feed Categories (u)', 'Create category (Enter)')
        expect(response.body).to include('data-keyboard-shortcuts-key="u"', 'data-keyboard-shortcuts-key="Enter"')
        expect(response.body).to include('Keyboard Shortcuts', 'New category')
      end
    end

    describe 'POST /feed_categories' do
      it 'creates a category and redirects to show' do
        expect {
          post feed_categories_path, params: { feed_category: { name: 'Business' } }
        }.to change(FeedCategory, :count).by(1)

        created_category = FeedCategory.find_by!(name: 'Business')
        expect(response).to redirect_to(created_category)
        follow_redirect!
        expect(response.body).to include('successfully created')
      end

      it 're-renders the form for invalid attributes' do
        expect {
          post feed_categories_path, params: { feed_category: { name: '' } }
        }.not_to change(FeedCategory, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(CGI.unescapeHTML(response.body)).to include("Name can't be blank")
      end
    end

    describe 'GET /feed_categories/:id/edit' do
      it 'renders the edit form' do
        get edit_feed_category_path(feed_category)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(feed_category.name)
        expect(response.body).to include('data-controller="keyboard-shortcuts"')
        expect(response.body).to include('Back to Feed Categories (u)', 'Update category (Enter)')
        expect(response.body).to include('data-keyboard-shortcuts-key="u"', 'data-keyboard-shortcuts-key="Enter"')
        expect(response.body).to include('Keyboard Shortcuts', 'Edit category')
      end
    end

    describe 'PATCH /feed_categories/:id' do
      it 'updates the category and redirects to show' do
        patch feed_category_path(feed_category), params: { feed_category: { name: 'Science' } }

        expect(response).to redirect_to(feed_category)
        expect(feed_category.reload.name).to eq('Science')
      end

      it 're-renders the form for invalid attributes' do
        patch feed_category_path(feed_category), params: { feed_category: { name: '' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(CGI.unescapeHTML(response.body)).to include("Name can't be blank")
      end
    end

    describe 'DELETE /feed_categories/:id' do
      it 'deletes an unused category and redirects to index' do
        expect { delete feed_category_path(feed_category) }.to change(FeedCategory, :count).by(-1)

        expect(response).to redirect_to(feed_categories_path)
        follow_redirect!
        expect(response.body).to include('successfully deleted')
      end

      it 'keeps a category with feeds and displays an alert' do
        create(:feed, feed_category: feed_category)

        expect { delete feed_category_path(feed_category) }.not_to change(FeedCategory, :count)

        expect(response).to redirect_to(feed_category)
        follow_redirect!
        expect(response.body).to include('cannot be deleted while feeds are assigned')
      end
    end
  end
end
