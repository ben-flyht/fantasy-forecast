class Statistic < ApplicationRecord
  # Disable Single Table Inheritance since we're using 'type' for stat type
  self.inheritance_column = :_type_disabled

  belongs_to :player
  belongs_to :gameweek

  validates :type, presence: true
  validates :value, presence: true, numericality: true
  validates :player_id, uniqueness: { scope: [ :gameweek_id, :type ] }

  # Scopes for common queries
  scope :for_gameweek, ->(gameweek) { where(gameweek: gameweek) }
  scope :for_player, ->(player) { where(player: player) }
  scope :of_type, ->(type) { where(type: type) }
end
