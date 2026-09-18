# MacronX

MacronX is a personal Open-Source Intelligence (OSINT) intake and analysis pipeline. It acts like an automated team of analysts: signals from devices, open-source feeds, social media scrapers, and APIs land in a single inbox, are automatically processed by LLM workflows, and then queued for your review via the web interface or `macronx-tui`.

The app is built around a simple idea: **capture -> process with AI -> analyze**. Most intelligence artifacts are designed to be automatically processed by workflows as they arrive. You simply review the generated insights—such as Executive Intelligence Briefs, trend analyses, or parsed transcripts—and then archive them.

## What it is

MacronX is a Rails application for collecting and processing intelligence artifacts at scale. It gives you authenticated inbox items with sources, tags, attachments, structured payloads, metadata, workflow assignment, processed state, and archive state.

Use it as the integration point between raw data collection and human analysis:

```text
Raw Signal -> API/webhook adapter -> inbox item -> automated LLM workflow -> analyst review (TUI/Web) -> archive
```

Today, MacronX provides the inbox, workflow, tagging, attachment, filtering, and API ingestion primitives. LLM-powered intelligence workflows are built on top of those primitives to automatically synthesize raw data.

## Why it exists

OSINT operations are most effective when analysts can rapidly collect context from multiple sources: news feeds, social media, intercepted audio, field imagery, and research notes. Without a common intake point, these artifacts become scattered across disconnected tools.

MacronX acts as the shared intelligence intake layer. It lets you capture raw signals quickly, preserve structured context, and automatically route them to LLMs for synthesis. Instead of spending time manually parsing raw data, you spend your time reading the generated reports and making strategic decisions.

MacronX is designed to stay secure and cheap to run. The Rails app, development database, and file storage run locally on your machine, ensuring sensitive intelligence stays private. Workflows are intended to call local LLMs (Ollama, LM Studio, mlx, and similar) wherever possible, reserving paid cloud APIs for cases that truly need them.

## Example workflows

### News Analysis

Automatically process your daily intelligence feeds. Articles are gathered into an inbox item, and an LLM workflow synthesizes the raw data to produce an Executive Intelligence Brief (EIB) identifying macro-trends, geopolitical risks, and technological shifts.
*See prompt: [news_analysis.md](prompts/news_analysis.md)*

### Social Discourse & Trends

Monitor platforms like X (Twitter) or Reddit for emerging narratives. A scraper pushes a JSON payload of trending conversations via the API, and an LLM workflow identifies competing factions, escalation risks, and the strategic implications of the discourse.
*See prompts: [x_trends.md](prompts/x_trends.md), [reddit_trends.md](prompts/reddit_trends.md)*

### Audio Intercepts & Transcription

Upload or pipe in raw audio files (e.g., from public speeches, intercepted comms, or analyst field notes). MacronX automatically transcribes the audio using local Whisper models, making the transcript available for subsequent LLM analysis, summarization, or translation.
*See prompt: [audio_transcript.md](prompts/audio_transcript.md)*

### Image Intelligence (IMINT)

Capture images from the field (e.g., via Meta glasses, drones, or web captures) and send them to a webhook adapter. The adapter creates an inbox item with the image attached, triggering an analyst-style threat assessment or geographical analysis workflow.
*See prompt: [image_analysis.md](prompts/image_analysis.md)*

### Manual fallback

When a raw signal cannot be analyzed automatically, it remains unprocessed in the inbox. From there it can be searched, filtered by source or tag, edited, archived, bulk-tagged, or manually marked as processed through an appropriate workflow.

## OSINT Prompt Library

MacronX includes a library of sample prompts tailored for OSINT analysts, located in the `prompts/` directory. These can be used directly as workflow templates:

- [**News Analysis**](prompts/news_analysis.md): Synthesize daily feeds into an Executive Intelligence Brief (EIB).
- [**X (Twitter) Trends**](prompts/x_trends.md): Analyze top discourse conversations for strategic narrative intelligence.
- [**Reddit Trends**](prompts/reddit_trends.md): Identify sentiment and emerging narratives from subreddit data.
- [**Image Analysis**](prompts/image_analysis.md): Conduct threat assessments and contextual analysis on imagery.
- [**Audio Transcription**](prompts/audio_transcript.md): Process and summarize transcribed audio intercepts.

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

## Terminal UI

A GPU-friendly Rust TUI is available for keyboard-driven work with MacronX. Built with ratatui, it features:

- Inline image preview via terminal graphics protocols (Kitty, iTerm2, Sixel)
- Inline audio playback with seek, volume controls, and waveform visualization
- Markdown body rendering with word-wrapping
- Keyboard-driven inbox listing, filtering by tag, and detail inspection

Get it at [macron1-automations/macronx-tui](https://github.com/macron1-automations/macronx-tui). Requires `cargo run` with a running MacronX API and `MACRONX_API_TOKEN` set.

## Daily feed digest

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

## Audio transcription

When an inbox item is created with an audio attachment (m4a, mp3, wav, etc.), the system automatically:

1. **Converts** the audio to mp3 using ffmpeg (for m4a files).
2. **Transcribes** the audio to text using self-hosted Whisper via `ruby_llm`.
3. **Stores** the transcript in `metadata["audio_transcript"]`.

The transcript is then available for workflows via the `{{audio_transcript}}` tag in the prompt template.

### Workflow prompt example

```text
Analyze the following audio transcription:

{{audio_transcript}}
```

When the workflow runs, `{{audio_transcript}}` is replaced with the transcribed text. Audio attachments are automatically excluded from the LLM request to avoid errors with models that don't support audio input.

### How it works

The `Inboxes::ProcessJob` coordinates attachment preprocessing before running workflows:

- Runs after an inbox item is created with a matching workflow tag.
- Preprocesses audio via `Audio::ConvertM4aToMp3Job`:
  - Converts m4a to mp3 (ffmpeg).
  - Transcribes the audio to text (`RubyLLM.transcribe` using `whisper-1` by default).
  - Stores the transcript in `metadata["audio_transcript"]`.
- Preprocesses images via `Image::ConvertHeicToJpegJob` (converts HEIC/HEIF to JPEG).
- Enqueues `Workflows::RunJob` once all preprocessing completes.

The `Workflows::Runner` then:

- Builds the prompt using the workflow template, replacing `{{audio_transcript}}` with the stored transcript.
- Excludes audio attachments from the LLM request when a transcript exists.
- Sends only the text prompt to the LLM.

### Supported audio formats

- m4a (audio/mp4, audio/x-m4a, audio/m4a)
- mp3 (audio/mpeg)
- wav, webm, ogg (any audio format supported by Whisper)

### Transcription models

The default transcription model is `whisper-1`. Other available models:

- `whisper-1` — default, good for general use
- `gpt-4o-transcribe` — faster, better for technical content
- `gpt-4o-mini-transcribe` — fastest, lowest cost
- `gpt-4o-transcribe-diarize` — identifies different speakers

Configure the default model in `.env` via `WHISPER_MODEL` (or in `config/initializers/ruby_llm.rb`):

```bash
WHISPER_MODEL=whisper-1
```

## LLM & Transcription configuration

The application uses **Ollama** for workflow execution and summary generation, and **Whisper** for audio transcription:

- **Workflows & Summaries**: Uses Ollama with `Qwen3.6-35B-A3B-FP8` by default.
  - `OLLAMA_API_BASE` (default: `http://localhost:1913/v1`, configure in `.env` for custom hosts, e.g. `http://100.95.26.48:1919/v1`)
  - `OLLAMA_MODEL` (default: `Qwen3.6-35B-A3B-FP8`)
- **Audio Transcription**: Uses a self-hosted Whisper speech-to-text service.
  - `WHISPER_API_BASE`: Base URL for the Whisper service (e.g. `http://100.96.219.81:9000`).
  - `WHISPER_API_KEY`: API key / token for the Whisper endpoint.
  - `WHISPER_MODEL`: Model identifier (default: `whisper-1`).
- **Model Registry**: Model capabilities and providers are registered in `config/models.json`.
- **Request Timeout**: Configured to 1800s (30 minutes) by default, overridable via `LLM_REQUEST_TIMEOUT`.

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

List and detail responses include `id`, `name`, `source`, `summary`, `body`, `tag` (tag name), `metadata`, `attachments`, `processed`, `archived`, `created_at`, and `updated_at`. They do not include `payload`.

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

### Exposing the app with ngrok

To reach the local app from other devices (for example, iOS Shortcuts or webhook adapters), tunnel it with ngrok:

```sh
ngrok start dev
```

The tunnel is defined in `~/.config/ngrok/ngrok.yml` (on macOS: `/Users/<user>/Library/Application Support/ngrok/ngrok.yml`):

```yaml
version: "3"
agent:
  authtoken: <your-authtoken>
tunnels:
  dev:
    proto: http
    url: <your-domain>
    addr: 3000
```

Create a static domain from the ngrok dashboard (https://dashboard.ngrok.com/domains), replace `url` in the config with it, and set it in `.env` so Rails allows the host:

```sh
NGROK_HOST=<your-domain>
```

If `NGROK_HOST` is set in `.env`, it is added to Rails' allowed hosts in `config/environments/development.rb`; restart the server after changing it.

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
