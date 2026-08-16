module TagsHelper
  # Preset Tailwind badge class combos offered in the tag color picker.
  # Defined here (rather than in the model) so tailwindcss-rails' default
  # content scan of app/helpers/**/*.rb generates these classes.
  TAG_COLOR_OPTIONS = [
    { name: "Neutral", classes: "bg-gray-100 text-gray-700" },
    { name: "Indigo",  classes: "bg-indigo-50 text-indigo-700" },
    { name: "Blue",    classes: "bg-blue-100 text-blue-700" },
    { name: "Emerald", classes: "bg-emerald-100 text-emerald-700" },
    { name: "Amber",   classes: "bg-amber-100 text-amber-800" },
    { name: "Red",     classes: "bg-red-100 text-red-700" },
    { name: "Purple",  classes: "bg-purple-100 text-purple-700" },
    { name: "Pink",    classes: "bg-pink-100 text-pink-700" }
  ].freeze

  def tag_color_options
    TAG_COLOR_OPTIONS
  end
end
