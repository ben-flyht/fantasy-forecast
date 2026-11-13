class User < ApplicationRecord
  NAME_LENGTH = 40
  USERNAME_LENGTH = 24
  LINK_INTERVAL = 2.minutes

  has_many :selections, dependent: :destroy
  has_secure_token :session_token

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :first_name, :last_name, :username, with: ->(name) { name.squish.presence }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :first_name, :last_name, length: { maximum: NAME_LENGTH }
  validates :username, length: { maximum: USERNAME_LENGTH }
  validates :username, format: { with: /\A[\p{L}\p{N}][\p{L}\p{N} _.'&-]*\z/, message: "can only use letters, numbers, spaces and . ' & - _" }, allow_nil: true
  validates :username, format: { without: /\A\d+\z/, message: "needs a letter in it" }, allow_nil: true
  validates :username, format: { without: /\Aanonymous\z/i, message: "is kept for players who haven't picked one" }, allow_nil: true
  validates :username, uniqueness: { case_sensitive: false }, allow_nil: true, if: :username_changed?

  generates_token_for :pack_link, expires_in: 1.hour do
    last_signed_in_at&.to_i
  end

  def send_link?
    return false if link_sent_at&.after?(LINK_INTERVAL.ago)

    update!(link_sent_at: Time.current)
  end

  def signed_in!
    update!(last_signed_in_at: Time.current)
    regenerate_session_token if session_token.blank?
  end

  def leaderboard_name = username || default_username

  def default_username = initialled_name || "Anonymous"

  def named? = username.present? || initialled_name.present?

  private

  def initialled_name = [ first_name, last_name&.first ].compact.join(" ").presence
end
