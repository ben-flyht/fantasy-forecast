class Forecast < ApplicationRecord
  belongs_to :player
  belongs_to :gameweek
  belongs_to :strategy, optional: true

  # Callbacks
  before_validation :assign_next_gameweek!

  # Uniqueness constraint: one forecast per player/gameweek
  validates :player_id, uniqueness: { scope: :gameweek_id }

  # Scopes
  scope :by_gameweek, ->(gameweek_id) { where(gameweek_id: gameweek_id) }
  scope :for_player, ->(player_id) { where(player_id: player_id) }
  scope :ranked, -> { where.not(rank: nil) }
  scope :by_rank, -> { order(rank: :asc) }
  scope :by_week, ->(week) { joins(:gameweek).where(gameweeks: { fpl_id: week }) }

  private

  def assign_next_gameweek!
    return if gameweek.present?

    next_gameweek = Gameweek.next_gameweek
    if next_gameweek
      self.gameweek = next_gameweek
    else
      errors.add(:gameweek, "No next gameweek available")
    end
  end
end
