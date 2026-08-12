# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create a default admin user for development. Change the email/password before running in production.
if Rails.env.development?
  admin = User.find_or_initialize_by(email: "admin@example.com")
  admin.password = "password"
  admin.password_confirmation = "password"
  admin.admin = true
  admin.save!
  puts "Dev user ready: #{admin.email} (password: password)"
end

# Seed the news tag and its auto-processing workflow.
news_tag = Tag.find_or_create_by!(name: "news")
Workflow.find_or_create_by!(name: "news-workflow") do |workflow|
  workflow.tag = news_tag
  workflow.prompt = <<~PROMPT.strip
    You are a news analyst. Analyze the following payload and produce a well-structured daily digest:

    {{payload}}
  PROMPT
end
puts "news-workflow ready (triggered by the 'news' tag)"
