module IconHelper
  # Renders an inline SVG icon from app/assets/images/icons/<name>.svg
  #
  # Usage:
  #   icon("home")
  #   icon("home", class: "w-6 h-6 text-red-500")
  #
  def icon(name, **options)
    options[:class] ||= "w-5 h-5"
    inline_svg_tag("icons/#{name}.svg", **options)
  end
end
