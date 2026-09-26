namespace :tags do
  desc "Import tags from a YAML file. Usage: bin/rails tags:import FILE=config/tags.yml"
  task import: :environment do
    file = ENV["FILE"] || ENV["TAGS_FILE"]
    result = Tags::ImportFromYaml.new(file).call

    puts "Created #{result.created.size} tags."
    puts "Skipped #{result.skipped.size} existing tags."
  end

  desc "Change a tag's id, remapping the inboxes and workflows that reference it. Usage: bin/rails tags:renumber_id OLD_ID=9 NEW_ID=14"
  task renumber_id: :environment do
    result = Tags::RenumberId.new(old_id: ENV["OLD_ID"], new_id: ENV["NEW_ID"]).call

    puts "Tag '#{result.tag.name}' is now id #{result.tag.id}."
    result.remapped.each { |label, count| puts "  #{label}: #{count} row(s) remapped." }
  rescue ArgumentError => e
    abort "Error: #{e.message}\nUsage: bin/rails tags:renumber_id OLD_ID=9 NEW_ID=14"
  end
end
