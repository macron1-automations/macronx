RubyLLM.configure do |config|
  models_file = Rails.root.join("config/models.json").to_s
  config.model_registry_file = models_file if File.exist?(models_file)
  ollama_base = ENV.fetch("OLLAMA_API_BASE", "http://localhost:1913/v1")
  ollama_base = "#{ollama_base.chomp('/')}/v1" unless ollama_base.end_with?("/v1")
  config.ollama_api_base = ollama_base
  config.default_model = ENV.fetch("OLLAMA_MODEL", "Qwen3.6-35B-A3B-FP8")
  config.ollama_api_key = ENV["OLLAMA_API_KEY"] if ENV["OLLAMA_API_KEY"].present?

  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.default_transcription_model = "whisper-1"

  config.request_timeout = ENV.fetch("LLM_REQUEST_TIMEOUT", 1800).to_i
  config.logger = Rails.logger
end

if File.exist?(RubyLLM.config.model_registry_file)
  RubyLLM.models.load_from_json!(RubyLLM.config.model_registry_file)
end
