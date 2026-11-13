class User < ApplicationRecord
  NAME_LENGTH = 40
  USERNAME_LENGTH = 24

  has_many :selections, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :first_name, :last_name, :username, with: ->(name) { name.squish.presence }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :first_name, :last_name, length: { maximum: NAME_LENGTH }
  validates :username, length: { maximum: USERNAME_LENGTH }
  validates :username, uniqueness: { case_sensitive: false }, allow_nil: true, if: :username_changed?

  generates_token_for :pack_link, expires_in: 7.days

  def leaderboard_name = username || initialled_name || "New player"

  def named? = username.present?

  private

  def initialled_name = ("#{first_name} #{last_name.first}." if first_name && last_name)
end
