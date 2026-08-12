module Workflows
  class Runner
    PLACEHOLDER = "{{payload}}"

    Result = Data.define(:inbox, :response)

    def initialize(inbox)
      @inbox = inbox
    end

    def call
      workflow = Workflow.find_by(tag_id: inbox.tag_id)
      return Result.new(inbox: inbox, response: nil) if workflow.nil?

      response = RubyLLM.chat.ask(build_prompt(workflow.prompt, inbox.payload))
      inbox.update!(body: response.content, processed: true, workflow_id: workflow.id, metadata: success_metadata(response))
      Result.new(inbox: inbox, response: response)
    rescue StandardError => error
      inbox.update_column(:metadata, failure_metadata(error))
      raise
    end

    private

    attr_reader :inbox

    def build_prompt(template, payload)
      template.gsub(PLACEHOLDER, payload.to_json)
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
