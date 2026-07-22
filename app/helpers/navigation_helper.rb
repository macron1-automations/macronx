module NavigationHelper
  # Main navigation items.
  # Each entry requires:
  #   label: display text
  #   path:  named route symbol (e.g. :root_path) or a URL string
  #   icon:  SVG filename stem under app/assets/images/icons/
  #
  # To add a new item, append a hash here — no other changes required.
  NAV_ITEMS = [
    { label: "Inbox",           path: :inboxes_path, icon: "inbox" },
    { label: "Feeds",           path: :feeds_path, icon: "rss" },
    { label: "Feed Categories", path: :feed_categories_path, icon: "tag" },
    { label: "Analytics",       path: :root_path, icon: "chart-bar" },
    { label: "Reports",         path: :root_path, icon: "document-text" },
    { label: "Users",           path: :root_path, icon: "users" },
    { label: "Billing",         path: :root_path, icon: "credit-card" },
    { label: "Projects",        path: :root_path, icon: "folder" }
  ].freeze

  NAV_SETTINGS_ITEMS = [
    { label: "Settings", path: :settings_api_token_path, icon: "cog-6-tooth" },
    { label: "Feedback", path: :root_path, icon: "chat-bubble-left-ellipsis" }
  ].freeze

  def navigation_items
    NAV_ITEMS
  end

  def navigation_settings_items
    NAV_SETTINGS_ITEMS
  end

  # Returns true when the given resolved URL path matches the current request.
  # Handles nested routes: /users/123/edit activates a "Users" item pointing at /users.
  # The root path is always matched exactly to avoid it being permanently active.
  def active_nav?(resolved_path)
    if resolved_path == root_path
      request.path == root_path
    else
      request.path.start_with?(resolved_path)
    end
  end

  # Returns Tailwind classes for a sidebar nav link based on active state.
  def nav_link_classes(resolved_path)
    base = "group flex items-center gap-x-3 rounded-md px-3 py-2 text-sm font-medium leading-6 transition-colors duration-150"
    if active_nav?(resolved_path)
      "#{base} bg-gray-800 text-white"
    else
      "#{base} text-gray-400 hover:bg-gray-800 hover:text-white"
    end
  end

  # Returns Tailwind classes for the icon inside a nav link.
  def nav_icon_classes(resolved_path)
    if active_nav?(resolved_path)
      "w-5 h-5 shrink-0 text-white"
    else
      "w-5 h-5 shrink-0 text-gray-400 group-hover:text-white transition-colors duration-150"
    end
  end
end
