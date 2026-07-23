require "ipaddr"
require "net/http"
require "rss"
require "uri"

module Feeds
  class FeedContentValidator
    class ValidationError < StandardError; end

    MAX_REDIRECTS = 5
    MAX_RESPONSE_SIZE = 5.megabytes
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    BLOCKED_NETWORKS = %w[
      0.0.0.0/8
      10.0.0.0/8
      100.64.0.0/10
      127.0.0.0/8
      169.254.0.0/16
      172.16.0.0/12
      192.0.0.0/24
      192.0.2.0/24
      192.168.0.0/16
      198.18.0.0/15
      198.51.100.0/24
      203.0.113.0/24
      224.0.0.0/4
      240.0.0.0/4
      ::/128
      ::1/128
      ::ffff:0:0/96
      100::/64
      2001:db8::/32
      fc00::/7
      fe80::/10
      ff00::/8
    ].map { |network| IPAddr.new(network) }.freeze

    def initialize(resolver: Addrinfo)
      @resolver = resolver
    end

    def validate!(url)
      document = RSS::Parser.parse(fetch(url), false)
      raise ValidationError, "Response is not a valid RSS or Atom feed" unless document

      entries = document.respond_to?(:items) ? document.items : document.entries
      raise ValidationError, "Feed contains no entries" if entries.blank?

      true
    rescue RSS::Error => error
      raise ValidationError, "Response is not a valid RSS or Atom feed: #{error.message}"
    end

    private

    attr_reader :resolver

    def fetch(url, redirects_remaining = MAX_REDIRECTS)
      uri = parse_uri(url)
      ip_address = resolve_public_ip(uri)
      perform_request(uri, ip_address) do |response|
        case response
        when Net::HTTPSuccess
          read_limited_body(response)
        when Net::HTTPRedirection
          raise ValidationError, "Feed redirected too many times" if redirects_remaining.zero?

          location = response["location"]
          raise ValidationError, "Feed redirect is missing a location" if location.blank?

          fetch(URI.join(uri.to_s, location).to_s, redirects_remaining - 1)
        else
          raise ValidationError, "Feed returned HTTP #{response.code}"
        end
      end
    rescue ValidationError
      raise
    rescue URI::InvalidURIError
      raise ValidationError, "Feed URL is invalid"
    rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => error
      raise ValidationError, "Feed could not be fetched: #{error.message}"
    end

    def parse_uri(url)
      uri = URI.parse(url)
      valid = uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.blank?
      raise ValidationError, "Feed URL must be a public HTTP or HTTPS URL" unless valid

      uri
    end

    def resolve_public_ip(uri)
      addresses = resolver.getaddrinfo(uri.host, uri.port, nil, :STREAM).map(&:ip_address).uniq
      raise ValidationError, "Feed host could not be resolved" if addresses.empty?
      raise ValidationError, "Feed URL resolves to a non-public address" if addresses.any? { |address| blocked?(address) }

      addresses.first
    rescue SocketError
      raise ValidationError, "Feed host could not be resolved"
    end

    def blocked?(address)
      ip_address = IPAddr.new(address)
      BLOCKED_NETWORKS.any? { |network| network.include?(ip_address) }
    rescue IPAddr::InvalidAddressError
      true
    end

    def perform_request(uri, ip_address)
      http = Net::HTTP.new(uri.host, uri.port)
      http.ipaddr = ip_address
      http.use_ssl = uri.is_a?(URI::HTTPS)
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Accept"] = "application/atom+xml, application/rss+xml, application/xml, text/xml, */*"
      request["User-Agent"] = "MacronX Feed Importer"
      result = nil
      http.request(request) { |response| result = yield response }
      result
    end

    def read_limited_body(response)
      body = +""
      response.read_body do |chunk|
        body << chunk
        raise ValidationError, "Feed response exceeds 5 MB" if body.bytesize > MAX_RESPONSE_SIZE
      end
      body
    end
  end
end
