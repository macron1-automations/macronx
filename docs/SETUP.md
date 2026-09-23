# Setup & Configuration

## LLM & Transcription configuration

The application uses **Ollama** for workflow execution and summary generation, and **Whisper** for audio transcription:

- **Workflows & Summaries**: Uses Ollama with `Qwen3.6-35B-A3B-NVFP4` by default.
  - `OLLAMA_API_BASE` (default: `http://localhost:1913/v1`, configure in `.env` for custom hosts, e.g. `http://100.95.26.48:1919/v1`)
  - `OLLAMA_MODEL` (default: `Qwen3.6-35B-A3B-NVFP4`)
- **Audio Transcription**: Uses a self-hosted Whisper speech-to-text service.
  - `WHISPER_API_BASE`: Base URL for the Whisper service (e.g. `http://100.96.219.81:9000`).
  - `WHISPER_API_KEY`: API key / token for the Whisper endpoint.
  - `WHISPER_MODEL`: Model identifier (default: `whisper-1`).
- **Model Registry**: Model capabilities and providers are registered in `config/models.json`.
- **Request Timeout**: Configured to 1800s (30 minutes) by default, overridable via `LLM_REQUEST_TIMEOUT`.

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
 
Seeds create:
- `admin@example.com` with a randomly generated secure password (printed to the terminal on initial creation, development only).
- The `news` tag and its auto-processing workflow (`news-workflow`) for automated daily RSS feed analysis.
 
To specify a custom password when seeding:
 
```sh
SEED_ADMIN_PASSWORD=your_password bin/rails db:seed
```

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
