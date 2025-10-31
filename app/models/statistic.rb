class Statistic < ApplicationRecord
  # Disable Single Table Inheritance since we're using 'type' for stat type
  self.inheritance_column = :_type_disabled

  belongs_to :player
  belongs_to :gameweek

  validates :type, presence: true
  validates :value, presence: true, numericality: true
  validates :player_id, uniqueness: { scope: [:gameweek_id, :type] }

  # Scopes for common queries
  scope :for_gameweek, ->(gameweek) { where(gameweek: gameweek) }
  scope :for_player, ->(player) { where(player: player) }
  scope :of_type, ->(type) { where(type: type) }

  # Get cumulative stat for a player up to a gameweek
  def self.cumulative(player, type, up_to_gameweek)
    where(player: player, type: type)
      .joins(:gameweek)
      .where("gameweeks.fpl_id <= ?", up_to_gameweek.fpl_id)
      .sum(:value)
  end

  # Get stat for specific gameweek
  def self.for_gameweek_and_type(player, gameweek, type)
    find_by(player: player, gameweek: gameweek, type: type)&.value || 0
  end
end
