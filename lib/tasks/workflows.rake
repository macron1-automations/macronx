namespace :workflows do
  desc "Re-run the workflow prompt for the most recent processed items with a tag. Usage: bin/rails workflows:reprocess COUNT=10 TAG=news"
  task reprocess: :environment do
    count = Integer(ENV["COUNT"], exception: false)
    abort "Usage: bin/rails workflows:reprocess COUNT=10 [TAG=news]" if count.nil? || count < 1

    tag_name = ENV["TAG"].presence || "news"

    puts "Reprocessing up to #{count} items tagged '#{tag_name}'..."
    result = Workflows::Reprocessor.new(tag_name: tag_name, limit: count, stream: $stdout).call

    puts "Reprocessed #{result.reprocessed.size} of #{result.count} items."
    puts "Skipped #{result.skipped.size} (no workflow)." if result.skipped.any?
    puts "Failed #{result.errors.size}." if result.errors.any?
  end
end
