class Manager < ApplicationRecord
  NICKNAME_LENGTH = 24

  has_many :pack_entries, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :nickname, with: ->(nickname) { nickname.squish }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :nickname, presence: { message: "is needed the first time you join" }, length: { maximum: NICKNAME_LENGTH }

  generates_token_for :pack_link, expires_in: 7.days

  def marked_entries = pack_entries.where.not(accuracy: nil)

  def accuracy = marked_entries.average(:accuracy)&.to_f

  def forecast_accuracy = marked_entries.average(:forecast_accuracy)&.to_f
end
