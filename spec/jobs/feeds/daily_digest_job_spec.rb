require 'rails_helper'

RSpec.describe Feeds::DailyDigestJob, type: :job do
  it 'runs a digest for every user that owns feeds' do
    user_a = create(:user)
    user_b = create(:user)
    create(:feed, user: user_a)
    create(:feed, user: user_b)
    create(:user)

    digest_a = instance_double(Feeds::DailyDigest, call: nil)
    digest_b = instance_double(Feeds::DailyDigest, call: nil)
    allow(Feeds::DailyDigest).to receive(:new).with(user: user_a).and_return(digest_a)
    allow(Feeds::DailyDigest).to receive(:new).with(user: user_b).and_return(digest_b)

    described_class.perform_now

    expect(digest_a).to have_received(:call)
    expect(digest_b).to have_received(:call)
    expect(Feeds::DailyDigest).to have_received(:new).exactly(2).times
  end

  it 'does nothing when no user owns feeds' do
    create(:user)

    expect(Feeds::DailyDigest).not_to receive(:new)

    described_class.perform_now
  end

  it 'runs a digest only for the specified user when passed a user instance' do
    user_a = create(:user)
    user_b = create(:user)
    create(:feed, user: user_a)
    create(:feed, user: user_b)

    digest_a = instance_double(Feeds::DailyDigest, call: nil)
    allow(Feeds::DailyDigest).to receive(:new).with(user: user_a).and_return(digest_a)

    described_class.perform_now(user_a)

    expect(digest_a).to have_received(:call)
    expect(Feeds::DailyDigest).to have_received(:new).once
  end

  it 'runs a digest only for the specified user when passed a user id' do
    user = create(:user)
    create(:feed, user: user)

    digest = instance_double(Feeds::DailyDigest, call: nil)
    allow(Feeds::DailyDigest).to receive(:new).with(user: user).and_return(digest)

    described_class.perform_now(user.id)

    expect(digest).to have_received(:call)
    expect(Feeds::DailyDigest).to have_received(:new).once
  end
end
