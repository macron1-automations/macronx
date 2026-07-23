require 'rails_helper'

RSpec.describe Feeds::FeedContentValidator do
  subject(:validator) { described_class.new }

  let(:rss_with_entry) do
    <<~XML
      <?xml version="1.0"?>
      <rss version="2.0"><channel><title>News</title><link>https://example.com</link><description>News</description>
      <item><title>Entry</title><link>https://example.com/entry</link></item></channel></rss>
    XML
  end

  let(:atom_with_entry) do
    <<~XML
      <?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom"><title>News</title><id>https://example.com</id><updated>2026-07-22T00:00:00Z</updated>
      <entry><title>Entry</title><id>entry-1</id><updated>2026-07-22T00:00:00Z</updated></entry></feed>
    XML
  end

  def stub_body(body)
    allow(validator).to receive(:fetch).and_return(body)
  end

  it 'accepts RSS with at least one item' do
    stub_body(rss_with_entry)

    expect(validator.validate!('https://example.com/feed')).to be true
  end

  it 'accepts Atom with at least one entry' do
    stub_body(atom_with_entry)

    expect(validator.validate!('https://example.com/feed')).to be true
  end

  it 'rejects an empty feed' do
    stub_body('<rss version="2.0"><channel><title>Empty</title><link>https://example.com</link><description>Empty</description></channel></rss>')

    expect { validator.validate!('https://example.com/feed') }
      .to raise_error(described_class::ValidationError, 'Feed contains no entries')
  end

  it 'rejects malformed feed content' do
    stub_body('<not-feed>')

    expect { validator.validate!('https://example.com/feed') }
      .to raise_error(described_class::ValidationError, /not a valid RSS or Atom feed/)
  end

  it 'rejects private resolved addresses before connecting' do
    address = instance_double(Addrinfo, ip_address: '127.0.0.1')
    resolver = class_double(Addrinfo, getaddrinfo: [ address ])
    private_validator = described_class.new(resolver: resolver)

    expect { private_validator.validate!('http://example.com/feed') }
      .to raise_error(described_class::ValidationError, /non-public address/)
  end

  it 'rejects unsupported URL schemes' do
    expect { validator.validate!('file:///etc/passwd') }
      .to raise_error(described_class::ValidationError, /public HTTP or HTTPS URL/)
  end

  it 'reports timeouts as validation errors' do
    allow(validator).to receive(:resolve_public_ip).and_return('203.0.114.1')
    allow(validator).to receive(:perform_request).and_raise(Net::ReadTimeout)

    expect { validator.validate!('https://example.com/feed') }
      .to raise_error(described_class::ValidationError, /could not be fetched/)
  end

  it 'reports non-success HTTP responses' do
    response = Net::HTTPNotFound.new('1.1', '404', 'Not Found')
    allow(validator).to receive(:resolve_public_ip).and_return('203.0.114.1')
    allow(validator).to receive(:perform_request).and_yield(response)

    expect { validator.validate!('https://example.com/feed') }
      .to raise_error(described_class::ValidationError, 'Feed returned HTTP 404')
  end

  it 'limits redirect chains' do
    response = Net::HTTPFound.new('1.1', '302', 'Found')
    response['location'] = '/next'
    allow(validator).to receive(:resolve_public_ip).and_return('203.0.114.1')
    allow(validator).to receive(:perform_request).and_yield(response)

    expect { validator.validate!('https://example.com/feed') }
      .to raise_error(described_class::ValidationError, 'Feed redirected too many times')
  end

  it 'rejects responses larger than five megabytes' do
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:read_body).and_yield('x' * (described_class::MAX_RESPONSE_SIZE + 1))

    expect { validator.send(:read_limited_body, response) }
      .to raise_error(described_class::ValidationError, /exceeds 5 MB/)
  end
end
