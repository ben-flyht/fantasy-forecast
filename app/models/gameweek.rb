class Gameweek < ApplicationRecord
  validates :fpl_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :start_time, presence: true

  # Associations
  has_many :performances, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :statistics, dependent: :destroy
  has_many :forecasts, dependent: :destroy

  scope :current, -> { where(is_current: true) }
  scope :next_upcoming, -> { where(is_next: true) }
  scope :finished, -> { where(is_finished: true) }
  scope :with_forecasts, -> { joins(:forecasts).distinct }
  scope :ordered, -> { order(:fpl_id) }

  def self.current_gameweek
    current.first
  end

  def self.next_gameweek
    next_upcoming.first
  end

  # The rest-of-season horizon: the next gameweek and every one after it. The
  # single source of truth shared by the forecaster that spans it and the tiering
  # that averages a season total back over it.
  def self.remaining
    anchor = next_gameweek
    return none unless anchor

    where("fpl_id >= ?", anchor.fpl_id).ordered
  end

  # How many weeks a rest-of-season score is spread over, and so what to divide it
  # by to read it as a single week. Never nought, because a season with no football
  # left in it still has to be safe to divide by.
  def self.remaining_count
    [ remaining.count, 1 ].max
  end
end
