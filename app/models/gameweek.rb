class Gameweek < ApplicationRecord
  validates :fpl_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :start_time, presence: true

  # Associations
  has_many :performances, dependent: :destroy

  scope :current, -> { where(is_current: true) }
  scope :next_upcoming, -> { where(is_next: true) }
  scope :finished, -> { where(is_finished: true) }
  scope :ordered, -> { order(:fpl_id) }

  def self.current_gameweek
    current.first
  end

  def self.next_gameweek
    next_upcoming.first
  end
end