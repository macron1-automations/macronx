# API Ingestion

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
- `PATCH /api/v1/inboxes/:id/archive`
- `PATCH /api/v1/inboxes/:id/unarchive`
- `GET /api/v1/tags`

List and detail responses include `id`, `name`, `source`, `summary`, `body`, `tag` (tag name), `metadata`, `attachments`, `processed`, `archived`, `created_at`, and `updated_at`. They do not include `payload`.
