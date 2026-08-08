require 'rails_helper'

RSpec.describe Feeds::RssFetcher do
  subject(:fetcher) { described_class.new }

  let(:rss_xml) do
    <<~XML
      <?xml version="1.0"?>
      <rss version="2.0"><channel><title>News</title><link>https://example.com</link><description>News</description>
      <item><title>Entry</title><link>https://example.com/entry</link></item></channel></rss>
    XML
  end

  it 'parses a valid RSS document' do
    allow(fetcher).to receive(:fetch_raw).and_return(rss_xml)

    expect(fetcher.fetch('https://example.com/feed').items.map(&:title)).to eq([ 'Entry' ])
  end

  it 'rejects malformed feed content' do
    allow(fetcher).to receive(:fetch_raw).and_return('<not-feed>')

    expect { fetcher.fetch('https://example.com/feed') }
      .to raise_error(described_class::FetchError, /not a valid RSS or Atom feed/)
  end

  it 'rejects private resolved addresses before connecting' do
    address = instance_double(Addrinfo, ip_address: '127.0.0.1')
    resolver = class_double(Addrinfo, getaddrinfo: [ address ])
    private_fetcher = described_class.new(resolver: resolver)

    expect { private_fetcher.fetch('http://example.com/feed') }
      .to raise_error(described_class::FetchError, /non-public address/)
  end

  it 'rejects unsupported URL schemes' do
    expect { fetcher.fetch('file:///etc/passwd') }
      .to raise_error(described_class::FetchError, /public HTTP or HTTPS URL/)
  end

  it 'reports timeouts as fetch errors' do
    allow(fetcher).to receive(:resolve_public_ip).and_return('203.0.114.1')
    allow(fetcher).to receive(:perform_request).and_raise(Net::ReadTimeout)

    expect { fetcher.fetch('https://example.com/feed') }
      .to raise_error(described_class::FetchError, /could not be fetched/)
  end

  it 'reports non-success HTTP responses' do
    response = Net::HTTPNotFound.new('1.1', '404', 'Not Found')
    allow(fetcher).to receive(:resolve_public_ip).and_return('203.0.114.1')
    allow(fetcher).to receive(:perform_request).and_yield(response)

    expect { fetcher.fetch('https://example.com/feed') }
      .to raise_error(described_class::FetchError, 'Feed returned HTTP 404')
  end

  it 'limits redirect chains' do
    response = Net::HTTPFound.new('1.1', '302', 'Found')
    response['location'] = '/next'
    allow(fetcher).to receive(:resolve_public_ip).and_return('203.0.114.1')
    allow(fetcher).to receive(:perform_request).and_yield(response)

    expect { fetcher.fetch('https://example.com/feed') }
      .to raise_error(described_class::FetchError, 'Feed redirected too many times')
  end

  it 'rejects responses larger than five megabytes' do
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:read_body).and_yield('x' * (described_class::MAX_RESPONSE_SIZE + 1))

    expect { fetcher.send(:read_limited_body, response) }
      .to raise_error(described_class::FetchError, /exceeds 5 MB/)
  end
end
