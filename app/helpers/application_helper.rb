module ApplicationHelper
  def render_markdown(text)
    return if text.blank?

    html = markdown_renderer.render(text)
    sanitizer.sanitize(html).html_safe
  end

  private

  def markdown_renderer
    @markdown_renderer ||= Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(link_attributes: { target: "_blank", rel: "noopener" }),
      autolink: true,
      tables: true,
      strikethrough: true,
      fenced_code_blocks: true,
      space_after_headers: true
    )
  end

  def sanitizer
    @sanitizer ||= Rails::HTML5::SafeListSanitizer.new
  end
end
