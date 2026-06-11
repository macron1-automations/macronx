require "rails_helper"

RSpec.describe "Rails" do
  it "loads the application" do
    expect(Rails.application).to be_present
  end
end
