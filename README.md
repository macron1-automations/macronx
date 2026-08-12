# MacronX

MacronX is EDC for your AI tools: a personal workflow inbox where signals from devices, shortcuts, webhooks, email adapters, and APIs can land in one place before being processed manually or routed into workflows.

The app is built around a simple idea: capture first, decide later. If an item can be processed automatically by source, tag, or workflow, it should move through the system. If it cannot, it stays in the inbox for human review.

## What it is

MacronX is a Rails application for collecting and organizing AI workflow inputs. It gives you authenticated inbox items with sources, tags, attachments, structured payloads, metadata, workflow assignment, processed state, and archive state.

Use it as the integration point between capture tools and downstream AI or productivity systems:

```text
Capture source -> API/email/webhook adapter -> inbox item -> tag/source routing -> workflow/manual review -> downstream system
```

Today, MacronX provides the inbox, workflow, tagging, attachment, filtering, and API ingestion primitives. Fully automated email ingestion, LLM analysis, external task-app export, and webhook-specific adapters are intended integration patterns built on top of those primitives.

## Why it exists

AI tools are most useful when they can receive context from the places where work actually happens: your phone, watch, glasses, camera roll, browser, command line, and task system. Without a common intake point, those captures become scattered one-off automations.

MacronX acts as the shared intake layer. It lets you capture raw input quickly, preserve structured context, attach files, and decide whether each item should be handled automatically or reviewed manually.

MacronX is designed to stay cheap to run. The Rails app, development database, and file storage run on your machine while you iterate locally. Workflows are intended to call local LLMs (Ollama, LM Studio, mlx, and similar) wherever possible, reserving paid cloud APIs for cases that truly need them.

## Example workflows

### Meta glasses image capture

Take a picture with Meta glasses and send it to an email or webhook adapter, for example: "hey Meta, email this to threat analyst." The adapter can create a MacronX inbox item with the image attached, a source such as `meta-glasses`, and a tag or workflow for analyst-style threat assessment.

The current app stores and organizes the item. The email adapter and LLM threat-analysis step are intended integrations that can be built around the API and workflow model.

### Research capture

An iOS Shortcut on Apple Watch or iPhone can collect a note, URL, voice transcript, or file and post it into MacronX. The item can then be tagged as research, assigned to a workflow, and reviewed or processed later.

### Task capture

An iOS Shortcut or webhook can create an inbox item for a task, reminder, or follow-up. A workflow can later transform that item and send it to a task app through that app's API.

### Manual fallback

When an item cannot be processed automatically, it remains unprocessed in the inbox. From there it can be searched, filtered by source or tag, edited, archived, bulk-tagged, or manually marked as processed through a workflow.

## Current capabilities

- Authenticated Rails web app with Devise.
- Inbox items with name, source, summary, body, JSON payload, JSON metadata, tags, attachments, processed state, and archive state.
- Manual creation and editing of inbox items.
- Source, tag, text search, and processed/archive filtering.
- Tags with configurable badge colors.
- Tag import from a user-editable YAML file.
- Workflows that can be assigned when processing one or more inbox items.
- Bulk actions for processing, archiving, unarchiving, tagging, and deleting inbox items.
- API token management from the Settings area after sign-in.
- JSON API ingestion for creating, listing, and fetching inbox items.
- Active Storage attachments, including multipart API uploads.
- Avo admin UI for admin users.
- Daily RSS feed digest: each user's feeds are fetched once a day and summarized into a single inbox item, grouped by category.

## Daily feed digest

Feeds are owned by the user who imported them. Once a day, a scheduled job fetches each user's feeds, collects articles published that day, and creates one inbox item per user whose payload is grouped by category.

For every feed, the job keeps at most the 10 most recent articles published today. Feeds with no articles published today are skipped, and individual feed failures (timeouts, HTTP errors, invalid feeds) are recorded in the inbox item's metadata without aborting the run.

The resulting inbox item:

- `source`: `feed-digest`
- `name`: `Daily feed digest — YYYY-MM-DD`
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

### Schedule

The job runs once a day at 6am via Solid Queue, configured in `config/recurring.yml` (`daily_feed_digest`, every day at 6am). It fires automatically when the Solid Queue worker is running (e.g. via `bin/dev`).

### Running manually

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

## Reprocessing workflow items

If you change a workflow's prompt (or your LLM setup) and want to re-run it on items that were already processed, you can re-process the most recent ones. This re-runs each item's tag workflow with the item's `payload` and overwrites the item's `body` and workflow metadata.

Re-process the 10 most recent processed items tagged `news`:

```sh
bin/rails workflows:reprocess COUNT=10
```

Point it at a different tag with `TAG`:

```sh
bin/rails workflows:reprocess COUNT=5 TAG=research
```

Behavior:

- Items are picked newest first, limited to `COUNT`.
- Only processed, non-archived items are included.
- Items whose tag has no workflow are skipped.
- A failed item does not abort the run; the error is recorded in the item's `metadata` and reported at the end.

## API ingestion

API requests authenticate with a bearer token:

```http
Authorization: Bearer <token>
```

Create or rotate your token from Settings after signing in.

Create an inbox item:

```http
POST /api/v1/inboxes
Content-Type: application/json
Authorization: Bearer <token>
```

```json
{
  "inbox": {
    "source": "ios-shortcut",
    "summary": "Research note from phone",
    "body": "Capture text, transcript, URL, or other context.",
    "payload": {
      "url": "https://example.com"
    },
    "metadata": {
      "device": "iphone"
    }
  }
}
```

Supported create fields:

- `source`
- `summary`
- `body`
- `payload`
- `metadata`
- `attachments` via multipart form data using `inbox[attachments][]`

The API also supports:

- `GET /api/v1/inboxes`
- `GET /api/v1/inboxes/:id`
- `GET /api/v1/tags`

## Local development

MacronX is meant to run entirely on your laptop. The web app, database, background jobs, and development file storage all use local services by default.

### Requirements

- Ruby 3.4.4
- Rails 8.1
- PostgreSQL

Development uses the local `macron_x_development` database. The test suite uses a separate local `macron_x_test` database created automatically by Rails.

### Database setup

Prepare the local database:

```sh
bin/rails db:prepare
```

Seeds create `admin@example.com` with password `password` (development only).

### App setup

Install dependencies and prepare the database:

```sh
bin/setup
```

Start the development server:

```sh
bin/dev
```

The app runs at:

```text
http://localhost:3000
```

`bin/setup` installs gems and runs `db:prepare`. `bin/dev` starts the Rails server and Tailwind CSS watcher through Foreman.

### Seed your tags

MacronX ships with a sample tag file at `config/tags.yml.example`. Copy it to `config/tags.yml`, edit the names and badge colors for your own workflow, then import it:

```sh
cp config/tags.yml.example config/tags.yml
bin/rails tags:import FILE=config/tags.yml
```

The importer creates missing tags and skips tags that already exist, using a case-insensitive name check to avoid duplicates. Existing tags are not overwritten.

The YAML format supports either strings or objects with `name` and optional `color`:

```yaml
tags:
  - Research
  - name: Review manually
    color: bg-purple-100 text-purple-700
```

## Security notes

This repository is intended to be safe for public collaboration, but local and production secrets must stay private.

Do not commit:

- `config/master.key`
- `.env`
- production credentials
- real API tokens
- real provider keys or passwords

Keep `config/credentials.yml.enc` encrypted. If this repository was previously private and used for a real deployment, rotate the Rails credentials and any connected service tokens before publishing it publicly.

## Roadmap / intended direction

- Email ingestion adapters for tools such as Meta glasses capture workflows.
- Webhook adapters for iOS Shortcuts, browser tools, command-line tools, and external automation systems.
- Automatic routing based on source, tag, payload, metadata, or attachment type.
- LLM-powered workflow execution via local models first (research, triage, analysis, transformation), with optional cloud fallbacks.
- Downstream exports into task managers, notes apps, ticketing systems, or custom APIs.
- Clear manual review queues for anything that cannot be processed confidently.
