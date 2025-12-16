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
  scope :active, -> { joins(:forecasts).where("forecasts.created_at >= ?", 30.days.ago).distinct }

  def self.bot
    find_by!(username: BOT_USERNAME, bot: true)
  end

  # Instance methods
  def display_name
    username
  end

  def beats_bot?
    return false if bot?

    rankings = ForecasterRankings.overall
    my_ranking = rankings.find { |r| r[:user_id] == id }
    my_ranking&.dig(:beats_bot) || false
  end

  def badge
    self.class.badge_for(bot: bot?, beats_bot: beats_bot?)
  end

  # Returns emoji badge based on user status
  # beats_bot: true if human has higher accuracy than bot
  def self.badge_for(bot:, beats_bot: false)
    if bot
      "🤖"
    elsif beats_bot
      "⚡" # Lightning - beats the bot
    else
      nil
    end
  end
end
