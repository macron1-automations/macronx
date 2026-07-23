FactoryBot.define do
  factory :feed_import do
    user
    source_filename { "feeds.csv" }

    after(:build) do |feed_import|
      next if feed_import.csv_file.attached?

      feed_import.csv_file.attach(
        io: StringIO.new("title,category,feed_url\nExample,News,https://example.com/feed.xml\n"),
        filename: "feeds.csv",
        content_type: "text/csv"
      )
    end
  end
end
