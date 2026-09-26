# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create the admin user used to sign in. Set SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD
# for a known login, otherwise a random password is generated and printed below.
# Re-running only changes the password when SEED_ADMIN_PASSWORD is present.
admin = User.find_or_initialize_by(email: ENV.fetch("SEED_ADMIN_EMAIL", "admin@example.com"))
admin.admin = true

if admin.new_record? || ENV["SEED_ADMIN_PASSWORD"].present?
  password = ENV["SEED_ADMIN_PASSWORD"].presence || SecureRandom.hex(16)
  admin.password = password
  admin.password_confirmation = password
  admin.save!
  puts "Admin user ready: #{admin.email} (password: #{password})"
else
  admin.save!
  puts "Admin user ready: #{admin.email} (password unchanged)"
end

# Seed the news tag and its auto-processing workflow.
news_tag = Tag.find_or_create_by!(name: "news")
workflow = Workflow.find_by(tag: news_tag) || Workflow.find_or_initialize_by(name: "news-workflow")
if workflow.new_record?
  workflow.tag = news_tag
  workflow.prompt = <<~PROMPT.strip
    You are a news analyst. Analyze the following payload and produce a well-structured daily digest:

    {{payload}}
  PROMPT
  workflow.save!
end
puts "#{workflow.name} ready (triggered by the 'news' tag)"
