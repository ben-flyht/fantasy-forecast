class User < ApplicationRecord
  BOT_USERNAME = "ForecasterBot".freeze

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  # Validations
  validates :username, presence: true, uniqueness: true, format: {
    with: /\A[a-zA-Z0-9]+\z/,
    message: "can only contain letters and numbers (no spaces or special characters)"
  }

  # Associations
  has_many :forecasts, dependent: :destroy
  has_many :strategies, dependent: :destroy

  # Scopes
  scope :bots, -> { where(bot: true) }
  scope :humans, -> { where(bot: false) }

  def self.bot
    find_by!(username: BOT_USERNAME, bot: true)
  end

  # Instance methods
  def display_name
    username
  end

  # Returns emoji badge based on user status
  # beats_bot: true if human has higher accuracy than bot
  def self.badge_for(bot:, beats_bot: false)
    if bot
      "🤖"
    elsif beats_bot
      "🦸" # Superhuman - beats the bot
    else
      nil
    end
  end
end
