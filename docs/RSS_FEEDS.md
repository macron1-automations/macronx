# Daily feed digest

Feeds are owned by the user who imported them. Once a day, a scheduled job fetches each user's feeds, collects articles published that day, and creates one inbox item per user whose payload is grouped by category.

For every feed, the job keeps at most the 10 most recent articles published today. Feeds with no articles published today are skipped, and individual feed failures (timeouts, HTTP errors, invalid feeds) are recorded in the inbox item's metadata without aborting the run.

The resulting inbox item:

- `source`: `feed-digest`
- `name`: `Daily Feed Digest`
- `summary`: a short count such as `3 categories, 5 feeds, 23 articles`
- `payload`: keyed by category name, e.g.

```json
{
  "Technology": [
    {
      "feed": "Tech News",
      "items": [
        { "title": "Post A", "summary": "Short summary...", "link": "https://example.com/a", "published_at": "2026-08-08T12:00:00Z" }
      ]
    }
  ]
}
```

- `metadata`: run timestamp, feeds processed, items collected, and any per-feed errors.
- `tags`: `["news"]`

## Workflows

The daily feed digest creates an inbox item with the `news` tag. In order for automated processing to occur, you must configure an LLM workflow associated with this `news` tag.

It is recommended to use the [News Analysis](../prompts/news_analysis.md) prompt when setting up this workflow. If the workflow and tag are properly configured, the digest will be automatically processed into an Executive Intelligence Brief.

## Schedule

The job runs once a day at 6am via Solid Queue, configured in `config/recurring.yml` (`daily_feed_digest`, every day at 6am). It fires automatically when the Solid Queue worker is running (e.g. via `bin/dev`).

## Running manually

Run it for all users with feeds:

```sh
bin/rails runner 'Feeds::DailyDigestJob.perform_now'
```

Enqueue it instead of running inline:

```sh
bin/rails runner 'Feeds::DailyDigestJob.perform_later'
```

Run it for a single user:

```sh
bin/rails runner 'user = User.find_by(email: "admin@example.com"); Feeds::DailyDigest.new(user: user).call'
```

Inspect the latest digest:

```sh
bin/rails runner 'puts Inbox.where(source: "feed-digest").last&.payload'
```
