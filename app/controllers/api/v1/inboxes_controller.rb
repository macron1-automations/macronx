module Api
  module V1
    class InboxesController < BaseController
      include Rails.application.routes.url_helpers

      resource_description do
        short "Inbox entries"
        description "Create and retrieve inbox records. Name is optional (auto-generated if omitted). File attachments require multipart/form-data."
        formats [ "json" ]
      end

      api :GET, "/v1/inboxes", "List all inbox entries"
      def index
        inboxes = Inbox.order(created_at: :desc)
        render json: inboxes.map { |i| serialize(i) }
      end

      api :GET, "/v1/inboxes/:id", "Fetch a single inbox entry"
      param :id, :number, required: true, desc: "Inbox ID"
      def show
        inbox = Inbox.find(params[:id])
        render json: serialize(inbox)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end

      api :POST, "/v1/inboxes", "Create a new inbox entry"
      param :inbox, Hash, required: true do
        param :name,     String, desc: "Display name (auto-generated if omitted)"
        param :source,   String, desc: 'Origin identifier (e.g. "ratatui")'
        param :summary,  String, desc: "Short human-readable summary"
        param :body,     String, desc: "Full text content"
        param :payload,  Hash,   desc: "Arbitrary JSON payload"
        param :metadata, Hash,   desc: "Arbitrary JSON metadata"
        param :attachments, Array, desc: "File attachments (multipart/form-data only; use inbox[attachments][] fields)"
      end
      def create
        inbox = Inbox.new(inbox_params_without_attachments)
        if inbox.save
          attach_files(inbox)
          render json: serialize(inbox), status: :created
        else
          render json: { errors: inbox.errors.as_json }, status: :unprocessable_content
        end
      end

      private

      def inbox_params
        params.require(:inbox).permit(:name, :source, :summary, :body, payload: {}, metadata: {}, attachments: [])
      end

      def inbox_params_without_attachments
        inbox_params.except(:attachments)
      end

      def attach_files(inbox)
        files = Array(params.dig(:inbox, :attachments)).select { |file| file.is_a?(ActionDispatch::Http::UploadedFile) }
        inbox.attachments.attach(files) if files.any?
      end

      def serialize(inbox)
        {
          id: inbox.id,
          name: inbox.name,
          source: inbox.source,
          summary: inbox.summary,
          body: inbox.body,
          payload: inbox.payload,
          metadata: inbox.metadata,
          attachments: inbox.attachments.map { |attachment| serialize_attachment(attachment) },
          created_at: inbox.created_at,
          updated_at: inbox.updated_at
        }
      end

      def serialize_attachment(attachment)
        {
          id: attachment.id,
          filename: attachment.filename.to_s,
          content_type: attachment.content_type,
          byte_size: attachment.byte_size,
          url: rails_blob_url(attachment, only_path: false, host: request.base_url)
        }
      end
    end
  end
end
