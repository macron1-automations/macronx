module Workflows
  class Runner
    PLACEHOLDER = "{{payload}}"
    BODY_PLACEHOLDER = "{{body}}"
    AUDIO_TRANSCRIPT_PLACEHOLDER = "{{audio_transcript}}"

    DEFAULT_SUMMARY_PROMPT = <<~PROMPT
      Write a short, plain-text summary of the text below so it can be read at a glance in an inbox list. Keep it to 1-2 sentences and at most ~150 characters. Do not use markdown, headings, lists, or quotes.

      {{body}}
    PROMPT

    Result = Data.define(:inbox, :response)

    def initialize(inbox)
      @inbox = inbox
    end

    def call
      workflow = Workflow.find_by(tag_id: inbox.tag_id)
      return Result.new(inbox: inbox, response: nil) if workflow.nil?

      response = RubyLLM.chat.ask(build_prompt(workflow.prompt, inbox.payload), **attachment_args(workflow))
      inbox.update!(body: response.content, processed: true, workflow_id: workflow.id, metadata: success_metadata(response))
      set_summary(workflow, response.content)
      Result.new(inbox: inbox, response: response)
    rescue StandardError => error
      inbox.update_column(:metadata, failure_metadata(error))
      raise
    end

    private

    attr_reader :inbox

    def build_prompt(template, payload)
      result = template.gsub(PLACEHOLDER, payload.to_json)
      result = result.gsub(AUDIO_TRANSCRIPT_PLACEHOLDER, body_content) if result.include?(AUDIO_TRANSCRIPT_PLACEHOLDER)
      result
    end

    def body_content
      inbox.metadata&.dig("audio_transcript").to_s
    end

    def attachment_args(workflow)
      return {} unless workflow.include_attachments? && inbox.attachments.any?

      attachments = inbox.attachments
      attachments = attachments.reject { |a| a.content_type&.start_with?("audio/") } if inbox.metadata&.key?("audio_transcript")

      { with: attachments }
    end

    def set_summary(workflow, body)
      summary = RubyLLM.chat.ask(build_summary_prompt(workflow, body)).content.to_s.strip
      inbox.update!(summary: summary.presence)
      inbox.update_column(:metadata, (inbox.metadata || {}).merge("summary_error" => nil))
    rescue StandardError => error
      inbox.update_column(:metadata, (inbox.metadata || {}).merge("summary_error" => error.message))
    end

    def build_summary_prompt(workflow, body)
      template = workflow.summary_prompt.presence || DEFAULT_SUMMARY_PROMPT
      return template.gsub(BODY_PLACEHOLDER, body) if template.include?(BODY_PLACEHOLDER)

      "#{template}\n\n#{body}"
    end

    def success_metadata(response)
      (inbox.metadata || {}).merge(
        "workflow_error" => nil,
        "workflow_model" => response.model_id,
        "workflow_tokens" => {
          "input" => response.tokens&.input,
          "output" => response.tokens&.output
        }
      )
    end

    def failure_metadata(error)
      (inbox.metadata || {}).merge("workflow_error" => error.message)
    end
  end
end
