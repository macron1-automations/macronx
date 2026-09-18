# Audio transcription

When an inbox item is created with an audio attachment (m4a, mp3, wav, etc.), the system automatically:

1. **Converts** the audio to mp3 using ffmpeg (for m4a files).
2. **Transcribes** the audio to text using self-hosted Whisper via `ruby_llm`.
3. **Stores** the transcript in `metadata["audio_transcript"]`.

The transcript is then available for workflows via the `{{audio_transcript}}` tag in the prompt template.

## Workflow prompt example

```text
Analyze the following audio transcription:

{{audio_transcript}}
```

When the workflow runs, `{{audio_transcript}}` is replaced with the transcribed text. Audio attachments are automatically excluded from the LLM request to avoid errors with models that don't support audio input.

## Supported audio formats

- m4a (audio/mp4, audio/x-m4a, audio/m4a)
- mp3 (audio/mpeg)
- wav, webm, ogg (any audio format supported by Whisper)
