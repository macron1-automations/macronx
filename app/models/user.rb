class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  API_TOKEN_LENGTH = 24

  has_many :inboxes, dependent: :destroy

  before_create :assign_api_token

  def self.find_by_api_token(raw_token)
    return nil if raw_token.blank?
    find_by(api_token_digest: Digest::SHA256.hexdigest(raw_token))
  end

  def api_token
    @plaintext_api_token
  end

  def regenerate_api_token
    raw = SecureRandom.base58(API_TOKEN_LENGTH)
    if update_column(:api_token_digest, Digest::SHA256.hexdigest(raw))
      @plaintext_api_token = raw
      true
    else
      false
    end
  end

  private

  def assign_api_token
    raw = SecureRandom.base58(API_TOKEN_LENGTH)
    self.api_token_digest = Digest::SHA256.hexdigest(raw)
    @plaintext_api_token = raw
  end
end
