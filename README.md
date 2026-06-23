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
- Workflows that can be assigned when processing one or more inbox items.
- Bulk actions for processing, archiving, unarchiving, tagging, and deleting inbox items.
- API token management from the Settings area after sign-in.
- JSON API ingestion for creating, listing, and fetching inbox items.
- Active Storage attachments, including multipart API uploads.
- Avo admin UI for admin users.

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

## Local development

Requirements:

- Ruby 3.4.4
- Rails 8.1
- PostgreSQL

Set up the app:

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

`bin/setup` installs dependencies and prepares the database. `bin/dev` starts the local Rails development process through Foreman.

## Security notes

This repository is intended to be safe for public collaboration, but local and production secrets must stay private.

Do not commit:

- `config/master.key`
- `.env*`
- production credentials
- real API tokens
- real provider keys or passwords

Keep `config/credentials.yml.enc` encrypted. If this repository was previously private and used for a real deployment, rotate the Rails credentials and any connected service tokens before publishing it publicly.

## Roadmap / intended direction

- Email ingestion adapters for tools such as Meta glasses capture workflows.
- Webhook adapters for iOS Shortcuts, browser tools, command-line tools, and external automation systems.
- Automatic routing based on source, tag, payload, metadata, or attachment type.
- LLM-powered workflow execution for research, triage, analysis, and transformation.
- Downstream exports into task managers, notes apps, ticketing systems, or custom APIs.
- Clear manual review queues for anything that cannot be processed confidently.
